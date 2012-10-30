/**
 * Controller script.
 */

/* It must be called before veins package is loaded. */

import("konoha");
//import("konoha.exception");
import("konoha.regexp");
import("konoha.math");
//import("konoha.sql");
import("posix.fd");
import("posix.file");
import("posix.process");
import("posix.socket");
import("posix.thread");
import("konoha.defined");

load("/home/yoshiaki/eclipse/workspace/Translate/konoha.veins/veins.k");
load("/home/yoshiaki/eclipse/workspace/Translate/Veins.aspen/settings.k");

if (!(defined(TRACE_USER))) {
    TRACE_USER = true;
}

//if (!(defined(Git))) {
//    class Git
//    {
//        String path;
//        String cmd;
//
//        Git(String path) {
//            this.path = path;
//            this.cmd = "/Users/chen_ji/Devel/git/Veins/aspen/subproc-git.sh -d \"" + path + "\"";
//        }
//
//        void init() {
//            exec(cmd + " -c init");
//        }
//
//        void add(String file) {
//            exec(cmd + " -c add -a \"" + file + "\"");
//        }
//
//        void commit(String msg) {
//            exec(cmd + " -c commit -a \"-m '" + msg + "'\"");
//        }
//
//        void commitAll(String msg) {
//            exec(cmd + " -c commit -a \"-a -m '" + msg + "'\"");
//        }
//    }
//}

HttpResponse redirect(String location)
{
    HttpResponse res = new HttpResponse();
    res["Location"] = location;
    res.status = 302;
    return res;
}

const DBPATH="mysql://aspen:konoha@localhost:3306";

Connection defineScripts()
{
	String str;
	str = "hrllo";
    return new Model("scripts", {
        "user": String,
        "id": String,
        "name": String,
        "readme": String,
        "js": String,
        "ks": String,
        "html": String,
        "date": String
    }, ["user", "id"]);
}

Model defineInquiries()
{
    return new Model("inquiries", {
        "id": AutoIncrementInt,
        "title": String,
        "name": String,
        "contents": String,
        "date": String
    }, ["id"]);
}

Model defineUserinfo()
{
    return new Model("userinfo", {
        "id": int,
        "email": String
    }, ["id"]);
}

Model defineCounter()
{
    return new Model("counter", {
        "page": String,
        "count": int
    }, ["page"]);
}

Template getDefaultTemplate(HttpRequest req)
{
    Template tpl = new Template();
    tpl.readFile("top.hdf");
    tpl["ID"] = req.session["id"];
    //tpl["Username"] = req.session["username"];
    //tpl["Password"] = req.session["password"];
    //tpl["Remember"] = req.session["remember"];
    //tpl["Practice"] = "on";
    return tpl;
}

@Public FILE FileStorage.openReadme(String user, String id)
{
    return FileStorage.open(user + "/" + id + "/readme.txt");
}

@Public FILE FileStorage.openJS(String user, String id)
{
    return FileStorage.open(user + "/" + id + "/k2js.k");
}

@Public FILE FileStorage.openKS(String user, String id)
{
    return FileStorage.open(user + "/" + id + "/ks.k");
}

@Public FILE FileStorage.openHTML(String user, String id)
{
    return FileStorage.open(user + "/" + id + "/index.html");
}

@Public FILE FileStorage.newReadme(String user, String id)
{
    return FileStorage.newFile(user + "/" + id + "/readme.txt");
}

@Public FILE FileStorage.newJS(String user, String id)
{
    return FileStorage.newFile(user + "/" + id + "/k2js.k");
}

@Public FILE FileStorage.newKS(String user, String id)
{
    return FileStorage.newFile(user + "/" + id + "/ks.k");
}

@Public FILE FileStorage.newHTML(String user, String id)
{
    return FileStorage.newFile(user + "/" + id + "/index.html");
}

@Public FILE FileStorage.newHistory(String user, String id)
{
    return FileStorage.newFile(user + "/" + id + "/history.txt");
}

@Public String Array.join(String separator)
{
    if (separator == null) {
        separator = ",";
    }
    String ret = "";
    for (int i = 0; i < this.getSize() - 1; i++) {
        ret = ret + this[i].toString() + separator;
    }
    if (this.getSize() > 0) {
        ret = ret + this[this.getSize() - 1];
    }
    return ret;
}

boolean isReservedWord(String word)
{
    return word in? ["action", "admin", "about", "check", "contact", "BUGS", "help"];
}

boolean isAdminUser(String user)
{
    return user in? ["0001_Midori_Sugaya", "chenji", "kimio"];
}

/* ------------------------------------------------------------------------ */

HttpResponse login(HttpRequest req, String[] args)
{
    if (req.method != "POST") {
        return null;
    }
    String username = req.params_post["username"];
    String password = req.params_post["password"];
    String remember = req.params_post["remember"];
    if (remember == "on") {
        req.session["username"] = username;
        req.session["password"] = password;
        req.session["remember"] = remember;
    }
    else {
        req.session.remove("username");
        req.session.remove("password");
        req.session.remove("remember");
    }
    User user = User.authenticate(username, password);
    if (user != null && user.name in? exec("ls " + $MEDIA_DIR).split("\n")) {
        req.session["id"] = user.name;
        if (TRACE_USER) {
            Map m = new Map();
            m["id"] = user.name;
            /*System.ntraceNotice("Aspen:SignIn", m);*/
        }
    }
    return redirect("/aspen/");
}

HttpResponse logout(HttpRequest req, String[] args)
{
    if (req.method != "POST") {
        return null;
    }
    if (TRACE_USER) {
        Map m = new Map();
        m["id"] = req.session["id"];
        /*System.ntraceNotice("Aspen:SignOut", m);*/
    }
    req.session.remove("id");
    return redirect("/aspen/");
}

HttpResponse viewer(HttpRequest req, String[] args)
{
    Template tpl = getDefaultTemplate(req);
    tpl["User.Name"] = args[0];
    tpl["User.Id"] = args[1];
//    Model scripts = defineScripts();
    Connection con = new Connection(DBPATH);
//    Map[] m = scripts.get("name", {
//        "user": args[0],
//        "id": args[1]
//    });
    ResultSet r = con.query("select name from scripts where user=" + args[0] + " and id=" + args[1]);
    if (r.next() == false) {
       return null;
    }
    String name = r.getString["name"];
    String readme = FileStorage.openReadme(args[0], args[1]).read();
    String js = FileStorage.openJS(args[0], args[1]).read();
    String ks = FileStorage.openKS(args[0], args[1]).read();
    String html = FileStorage.openHTML(args[0], args[1]).read();
    if (name != null && name != "") {
        tpl["Code.Name"] = name.convert(to:durl);
    }
    tpl["Code.Body.Readme"] = readme;
    tpl["Code.Body.Js"] = js;
    tpl["Code.Body.Ks"] = ks;
    tpl["Code.Body.Html"] = html;
//    Model counter = defineCounter();
    String page = args[0] + "/" + args[1];
//    m = counter.get("count", {
//        "page": page
//    });
    ResultSet r = con.query("select count from counter where page=" + page);
    
    int count = 0;
    if (r.next() == false) {
//        counter.set({
//            "page": page,
//            "count": 0
//        });
        con.query("insert into counter (page, count) values(" + page + ", " + 0 + ")");
    }
    else {
//        count = m[0]["count"];
    	count = r.getInt("count");
//        counter.update({
//            "count": count + 1
//        }, {"page": page});
    	count = count + 1;
    	con.query("update counter set count=" + count + " where page=" + page);
    }
    tpl["Code.Viewcount"] = count;
    TemplateContext ctx = new TemplateContext();
    if (req.session["id"] == args[0]) {
        tpl["Myself"] = 1;
    }
    else {
        if (args.getSize() == 3) {
            args.pop()
            return redirect("/aspen/" + args.join("/"));
        }
    }
    ctx.parseFile("viewer.cs");
    if (TRACE_USER) {
        Map m = new Map();
        m["id"] = req.session["id"];
        m["target"] = args[0];
        m["watching"] = args[1];
        /*System.ntraceNotice("Aspen:Viewer", m);*/
    }
    return new HttpResponse(tpl.render(ctx));
}

void reportBug(String user, String id) {
    FileStorage.mkdir("BUGS", 0755);
    Date d = new Date();
    String fname = d.getYear().toString() + d.getMonth().toString() + d.getDay().toString();
    fname = fname + d.getHours().toString() + d.getMinutes().toString() + d.getSeconds().toString();
    fname = fname + "_" + user + "_" + id + ".k";
    FILE ous = FileStorage.newFile("BUGS/" + fname);
    FILE ins = FileStorage.openJS(user, id);
    ous.write(ins.read());
    ous.close();
    ins.close();
}

String compile(FILE body, String k2jspath, String scriptpath) {
    body.close();
    String[] result = exec(k2jspath + " -c -i " + scriptpath + " 2>&1").split("\n");
    result.pop()
    Json j = new Json();
    Json[] errs = [];
    Json[] infos = [];
    Json[] warns = [];
    RegExp r = new RegExp(" - \\((\\w+\\.k)\\:(\\d+)\\) \\((\\w+)\\) (.+)");
    foreach (String line in result) {
        String[] reg = line.match(r);
        if (reg.getSize() > 0) {
            Json j2 = new Json();
            j2["line"] = reg[2];
            j2["message"] = reg[4];
            if (!(reg[1] == "compiler.k")) {
                switch (reg[3]) {
                	if(reg[3] == "error"){
                		errs.add(j2);
                	}
                	else if(reg[3] == "warning"){
                		warns.add(j2);
                	}
                	else if(reg[3] == "info"){
                		infos.add(j2);
                	}
                }
            }
        }
    }
    if (errs.getSize() > 0) {
        j["error"] = true;
        j["errormsg"] = errs;
    }
    if (infos.getSize() > 0) {
        j["info"] = true;
        j["infomsg"] = infos;
    }
    if (warns.getSize() > 0) {
        j["warning"] = true;
        j["warningmsg"] = warns;
    }
    return j.stringify();
}

HttpResponse konoha2js(HttpRequest req, String[] args)
{
    if (req.method == "POST") {
        return null;
    }
    String user = args[0];
    String id = args[1];
    String requestedType = args[2];
    if (requestedType == null) {
        requestedType = "js";
    }
//    Model scripts = defineScripts();
    Connection con = new Connection(DBPATH);
//    Map[] m = scripts.get("name", {
//        "user": user,
//        "id": id
//    });
    ResultSet r = con.query("select name from scripts where user=" + user + " and id=" + id);
    if (r.next() == false) {
        return null;
//     }
    FILE body = FileStorage.openJS(user, id);
    String scriptpath = body.path;
    HttpResponse res = new HttpResponse();
    String k2jspath = "/usr/local/bin/konoha2js";
    if (requestedType == "js") {
        body.close();
        //res["Access-Control-Allow-Origin"] = "http://konohascript.org";
        res["Content-Type"] = "application/javascript";
        int max_loop_count = 1000000000;
        res.content = exec(k2jspath + " -j -r -l " + max_loop_count + " -i " + scriptpath);
        if (res.content == "") {
            // a SEGV may occurred on konoha2js
            reportBug(user, id);
            res.content = "function konoha() {\nthis.ERR = "";\nthis.printOUT = function() {};\nthis.printERR = function() {\nif (this.ERR == "") return;\nvar strings = this.ERR.split(\"\\n\");\nvar body = document.getElementsByTagName('body').item(0);\nfor (var i = 0; i < strings.length; i++) {\nbody.appendChild(document.createTextNode(strings[i]));\nbody.appendChild(document.createElement('br'));\n}\n};\n}\nkonoha = new konoha();\nfunction konoha_main() {\nthrow(\"Compile Error!!: Your script is reported as a reproducible code. Sorry.\");\n}\n";
        }
    }
    else if (requestedType == "html") {
        body.close();
        //String ret = exec(k2jspath + " -j -r -i " + path);
        //ret = "<script type=\"text/javascript\">\n" + ret + "\n</script>\n</head>";
        //String replacetxt = "</head>";
        FILE html = FileStorage.openHTML(user, id);
        //res.content += html.read().decode().replace(replacetxt, ret);
        res.content = res.content + html.read();
        html.close();
        if (TRACE_USER) {
            Map m = new Map();
            m["id"] = req.session["id"];
            m["target"] = user;
            m["running"] = id;
            /*System.ntraceNotice("Aspen:Konoha2JS", m);*/
        }
    }
    else if (requestedType == "compile") {
        //res["Access-Control-Allow-Origin"] = "http://konohascript.org";
        res["Content-Type"] = "application/json; charset=UTF-8";
        res.content = compile(body, k2jspath, scriptpath);
        if (TRACE_USER) {
            Map m = new Map();
            m["id"] = req.session["id"];
            m["target"] = user;
            m["compiling"] = id;
            /*System.ntraceNotice("Aspen:Konoha2JS", m);*/
        }
    }
    else if (requestedType == "javac") {
        body.close();
//        Model scripts = defineScripts();
        Connection con = new Connection(DBPATH);
        String scriptname;
//        Map[] m = scripts.get("name", {
//            "user": user,
//            "id": id
//        });
        ResultSet r = con.query("select name from scripts where user=" + user + " and id=" + id);
//        if (m.getSize() == 1) {
//            scriptname = m[0]["name"];
//        }
//        else {
//            return null;
//        }
        if (r.next() == false) {
        	return null;
        }
        scriptname = r.getString("name");
        String javacpath = "/usr/bin/javac -encoding UTF8";
        res["Content-Type"] = "application/json; charset=UTF-8";
        if (System.stat(FileStorage.root + user + "/javac") == null) {
            FileStorage.mkdir(user + "/javac", 0755);
        }
        if (System.stat(FileStorage.root + user + "/javac" + id) == null) {
            FileStorage.mkdir(user + "/javac/" + id, 0755);
        }
        String javapath = FileStorage.root + user + "/javac/" + id + "/" + scriptname;
        System.symlink(scriptpath, javapath);
        String result = exec(javacpath + " -d " + TMP_DIR + " " + javapath + " 2>&1");
        Json j = new Json();
        if (result != "") {
            j["error"] = true;
            j["errormsg"] = result.replace(javapath, scriptname);
        }
        res.content = j.stringify();
        if (TRACE_USER) {
            Map m = new Map();
            m["id"] = req.session["id"];
            m["target"] = user;
            m["javacompiling"] = id;
            /*System.ntraceNotice("Aspen:Konoha2JS", m);*/
        }
    }
    else if (requestedType == "ks") {
        res["Content-Type"] = "text/plain; charset=UTF-8";
        res.content = body.read();
        body.close();
    }
    else if (requestedType == "memview") {
        body.close();
        Template tpl = getDefaultTemplate(req);
        tpl["User"] = user;
        tpl["Script"] = id;
        TemplateContext ctx = new TemplateContext();
        ctx.parseFile("canvas.cs");
        res.content = tpl.render(ctx);
        if (TRACE_USER) {
            Map m = new Map();
            m["id"] = req.session["id"];
            m["target"] = user;
            m["memviewing"] = id;
            /*System.ntraceNotice("Aspen:Konoha2JS", m);*/
        }
    }
    else if (requestedType == "download") {
//        String name = m[0]["name"];
    	name = r.getString("name");
        if (name != null && name != "") {
            res["Content-Type"] = "text/plain; charset=UTF-8";
            if (!(name.endsWith(".java"))) {
                name = name + ".java";
            }
            res["Content-Disposition"] = "attachment; filename=\"" + name + "\"";
            res.content = body.read();
            res["Content-Length"] = (to String)res.content.size;
            if (TRACE_USER) {
                Map m = new Map();
                m["id"] = req.session["id"];
                m["target"] = user;
                m["downloading"] = id;
                /*System.ntraceNotice("Aspen:Konoha2JS", m);*/
            }
        }
    }
    else {
        args.pop();
        return redirect("/aspen/" + args.join("/"));
    }
    return res;
}

HttpResponse usertop(HttpRequest req, String[] args)
{
    String user = args[0];
    if (!(User.hasUser(user))) {
        if (req.session["id"] == user) {
            req.session.remove("id");
        }
        return redirect("/aspen/");
    }
    if (args.getSize() == 2) {
        return viewer(req, args);
    }
    else if (args.getSize() == 3) {
        return konoha2js(req, args);
    }
    Template tpl = getDefaultTemplate(req);
    tpl["Info.0.key"] = "ID";
    tpl["Info.0.value"] = user;
    if (req.session["id"] == user) {
        tpl["Myself"] = 1;
    }
    Array codelist = [];
//    Model scripts = defineScripts();
    Connection con = new Connection(DBPATH);
    ResultSet r = con.query("select id and name and date from scripts where user=" + user);
//    foreach (Map m in scripts.get("id, name, date", {"user": user})) {
//        String id = m["id"];
//        String name = m["name"];
//        codelist.add({
//            "Id": id,
//            "Name": name.convert(to:durl),
//            "Date": m["date"]
//        });
//    }
    while (r.next() == true) {
      String id = m["id"];
      String name = m["name"];
      codelist.add({
          "Id": id,
          "Name": name.convert(to:durl),
          "Date": m["date"]
      });
    }
    tpl["User"] = user;
    if (isAdminUser(user)) {
        tpl["Admin"] = 1;
    }
    tpl["Code"] = codelist;
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("user.cs");
    if (TRACE_USER) {
        Map m = new Map();
        m["id"] = req.session["id"];
        m["watching"] = user;
        /*System.ntraceNotice("Aspen:User", m);*/
    }
    return new HttpResponse(tpl.render(ctx));
}

HttpResponse top(HttpRequest req, String[] args)
{
    if (req.session["id"] != null) {
        return redirect("/aspen/" + req.session["id"]);
    }
    Template tpl = getDefaultTemplate(req);
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("top.cs");
    return new HttpResponse(tpl.render(ctx));
}

HttpResponse about(HttpRequest req, String[] args)
{
    Template tpl = getDefaultTemplate(req);
    tpl.readFile("about.hdf");
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("about.cs");
    return new HttpResponse(tpl.render(ctx));
}

HttpResponse signup(HttpRequest req, String[] args)
{
    Template tpl = getDefaultTemplate(req);
    tpl.readFile("signup.hdf");
    TemplateContext ctx = new TemplateContext();
    if (req.method != "POST") {
        ctx.parseFile("form.cs");
        return new HttpResponse(tpl.render(ctx));
    }
    String username = req.params_post["username"];
    String password = req.params_post["password"];
    String email = req.params_post["email"];
    RegExp r = new RegExp("^([\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4})?$");
    RegExp r2 = new RegExp("^[a-zA-Z0-9_]{1,48}$");
    if (isReservedWord(username)) {
        Map error = {
            "Title": "Username is invalid.",
            "Contents": "You cannot use '" + username + "' as a username."
        };
        tpl["Form.Inputs.0.Input.Value"] = username;
        tpl["Form.Inputs.1.Input.Value"] = email;
        tpl["Error"] = error;
        ctx.parseFile("form.cs");
        if (TRACE_USER) {
            Map m = new Map();
            m["username"] = username;
            m["email"] = email;
            /*System.ntraceFailed("Aspen:SignUp", m);*/
        }
        return new HttpResponse(tpl.render(ctx));
    }
    if (username.search(r2) < 0) {
        Map error = {
            "Title": "Username is invalid.",
            "Contents": "Username can only contain letters, numbers and '_'."
        };
        tpl["Form.Inputs.0.Input.Value"] = username;
        tpl["Form.Inputs.1.Input.Value"] = email;
        tpl["Error"] = error;
        ctx.parseFile("form.cs");
        if (TRACE_USER) {
            Map m = new Map();
            m["username"] = username;
            m["email"] = email;
            /*System.ntraceFailed("Aspen:SignUp", m);*/
        }
        return new HttpResponse(tpl.render(ctx));
    }
    if (email.search(r) < 0) {
        Map error = {
            "Title": "email is invalid.",
            "Contents": "Cannot create user '" + username + "'. Please retry."
        };
        tpl["Form.Inputs.0.Input.Value"] = username;
        tpl["Form.Inputs.1.Input.Value"] = email;
        tpl["Error"] = error;
        ctx.parseFile("form.cs");
        if (TRACE_USER) {
            Map m = new Map();
            m["username"] = username;
            m["email"] = email;
            /*System.ntraceFailed("Aspen:SignUp", m);*/
        }
        return new HttpResponse(tpl.render(ctx));
    }
    User user = User.addUser(username, password);
    if (user == null) {
        Map error = {
            "Title": "Username is invalid.",
            "Contents": "Cannot create user '" + username + "'. Please retry."
        };
        tpl["Form.Inputs.0.Input.Value"] = username;
        tpl["Form.Inputs.1.Input.Value"] = email;
        tpl["Error"] = error;
        ctx.parseFile("form.cs");
        if (TRACE_USER) {
            Map m = new Map();
            m["username"] = username;
            m["email"] = email;
            /*System.ntraceFailed("Aspen:SignUp", m);*/
        }
        return new HttpResponse(tpl.render(ctx));
    }
//    Model userinfo = defineUserinfo();
//    userinfo.add({
//        "id": user.id,
//        "email": email
//    });
    Connection con = new Connection(DBPATH);
    con.query("insert into userinfo (id, email) values(" + user.id ", " + email + ")");
    FileStorage.mkdir(username, 0755);
    req.session["id"] = user.name;
    if (TRACE_USER) {
        Map m = new Map();
        m["newid"] = user.name;
        m["email"] = email;
        /*System.ntraceNotice("Aspen:SignUp", m);*/
    }
    return redirect("/aspen/");
}

HttpResponse check(HttpRequest req, String[] args)
{
    if (req.method == "POST") {
        return null;
    }
    HttpResponse res = new HttpResponse();
    res["Content-Type"] = "application/json; charset=utf-8";
    Json j = new Json();
    if(args[1] == "username"){
        RegExp r = new RegExp("^[a-zA-Z0-9_]{1,48}$");
        String username = req.params_get["username"];
        if (User.hasUser(username) ||
                isReservedWord(username)) {
            j["exists"] = true;
        }
        else {
            j["exists"] = false;
        }
        if (username.search(r) < 0) {
            j["error"] = true;
        }
        else {
            j["error"] = false;
        }
    }
    else if(args[1] == "email"){
        RegExp r = new RegExp("^([\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4})?$");
        String email = req.params_get["email"];
        if (email.search(r) < 0) {
            j["error"] = true;
        }
        else {
            j["error"] = false;
        }
    }
    else{
        return null;
        break;
    }
    res.content = j.stringify();
    return res;
}

HttpResponse save(HttpRequest req, String[] args)
{
    if (req.method != "POST") {
        return null;
    }
    HttpResponse res = new HttpResponse();
    res["Content-Type"] = "application/json; charset=utf-8";
    Json j = new Json();
    String user = req.params_post["user"];
    String id = req.params_post["id"];
    String readme = req.params_post["readme"];
    String js = req.params_post["js"];
    String ks = req.params_post["ks"];
    String html = req.params_post["html"];
    String history = req.params_post["history"];
    if (user != req.session["id"]) {
        j["error"] = true;
        j["message"] = "Parameter 'user' is invalid.";
        res.content = j.stringify();
        if (TRACE_USER) {
            Map m = new Map();
            m["id"] = req.session["id"];
            m["target"] = user;
            m["saving"] = id;
            /*System.ntraceFailed("Aspen:Save", m);*/
        }
        return res;
    }
    Map m = new Map();
    FILE ous_readme = FileStorage.newReadme(user, id);
    FILE ous_js = FileStorage.newJS(user, id);
    FILE ous_ks = FileStorage.newKS(user, id);
    FILE ous_html = FileStorage.newHTML(user, id);
    FILE ous_history = FileStorage.newHistory(user, id);
    String git_path = (to String)ous_readme.path;
    git_path = git_path.substring(0, git_path.lastIndexOf("/"));
    Git g = new Git(git_path);
    ous_readme.print(readme);
    ous_js.print(js);
    ous_ks.print(ks);
    ous_html.print(html);
    ous_history.print(history);
    ous_readme.close();
    ous_js.close();
    ous_ks.close();
    ous_html.close();
    ous_history.close();
    g.add("*");
    g.commit("save commit");
    if (readme != "" && readme != null) {
        m["readme"] = readme.convert(to:url);
    }
    if (js != "" && js != null) {
        m["js"] = js.convert(to:url);
    }
    if (ks != "" && ks != null) {
        m["ks"] = ks.convert(to:url);
    }
    if (html != "" && html != null) {
        m["html"] = html.convert(to:url);
    }
    m["date"] = (to String)new Date();
    j["message"] = "Script saved successfully.";
    res.content = j.stringify();
    if (TRACE_USER) {
        Map m = new Map();
        m["id"] = req.session["id"];
        m["saving"] = id;
        /*System.ntraceNotice("Aspen:Save", m);*/
    }
    return res;
}

HttpResponse create(HttpRequest req, String[] args)
{
    String js_tpl = "// your code goes here.";
    String html_tpl = "<!DOCTYPE html>\n<html>\n<head>\n<title>sample</title>\n<!-- konoha2js code goes here -->\n<script src=\"%src%\"></script>\n<!-- include this if you use js.jquery package -->\n<script src=\"%static%/js/libs/jquery-1.7.1.min.js\"></script>\n<script>\nfunction runmain() {\ntry {\nkonoha_main();\n} catch (e) {\nif (typeof(e) == \"string\") {\nkonoha.ERR = e;\n}\nelse {\nthrow e;\n}\n}\nkonoha.printERR();\nkonoha.printOUT();\n}\n</script>\n</head>\n<body onload=\"runmain();\">\n</body>\n</html>";
    if (req.session["id"] == null) {
        return null;
    }
    if (req.method == "GET") {
        Template tpl = getDefaultTemplate(req);
        tpl.readFile("create.hdf");
        TemplateContext ctx = new TemplateContext();
        ctx.parseFile("form.cs");
        return new HttpResponse(tpl.render(ctx));
    }
    String codename = req.params_post["codename"];
    if (codename.trim().getSize() == 0 || codename.getSize() >= 128) {
        Map error = new Map();
        if (codename.trim().getSize() == 0) {
            error["Title"] = "Name is empty.";
        }
        else {
            error["Title"] = "Name is too long (should be no longer than 128).";
        }
        Template tpl = getDefaultTemplate(req);
        tpl.readFile("create.hdf");
        tpl["Form.Inputs.0.Input.Value"] = codename;
        tpl["Error"] = error;
        TemplateContext ctx = new TemplateContext();
        ctx.parseFile("form.cs");
        if (TRACE_USER) {
            Map m = new Map();
            m["id"] = req.session["id"];
            m["creating"] = codename;
            /*System.ntraceFailed("Aspen:Create", m);*/
        }
        return new HttpResponse(tpl.render(ctx));
    }
    HttpResponse res = new HttpResponse();
    Date d = new Date();
    String id = d.getYear().toString();
    id = id + d.getMonth().toString();
    id = id + d.getDay().toString();
    id = id + d.getHours().toString();
    id = id + d.getSeconds().toString();
    String sessionid = req.session["id"];
    if (!FileStorage.mkdir(sessionid + "/" + id, 0755)) {
        if (TRACE_USER) {
            Map m = new Map();
            m["id"] = req.session["id"];
            m["creating"] = codename;
            /*System.ntraceFailed("Aspen:Create", m);*/
        }
        return redirect("/aspen/");
    }
//  Model scripts = defineScripts();
    Connection con = new Connection(DBPATH);
    FILE ous_readme = FileStorage.newReadme(sessionid, id);
    FILE ous_js = FileStorage.newJS(sessionid, id);
    FILE ous_ks = FileStorage.newKS(sessionid, id);
    FILE ous_html = FileStorage.newHTML(sessionid, id);
    String git_path = ous_readme.path.toString();
    git_path = git_path.substring(0, git_path.lastIndexOf("/"));
    Git g = new Git(git_path);
    html_tpl = html_tpl.replace("%src%", "/aspen/" + sessionid + "/" + id + "/js");
    html_tpl = html_tpl.replace("%static%", $STATIC_URL);
    ous_js.print(js_tpl);
    ous_html.print(html_tpl);
    ous_readme.close();
    ous_js.close();
    ous_ks.close();
    ous_html.close();
    g.init();
    g.add("*");
    g.commit("initial commit");
    scripts.set({
        "user": sessionid,
        "id": id,
        "name": codename.convert(to:url),
        "js": js_tpl.convert(to:url),
        "html": html_tpl.convert(to:url),
        "date": (to String)d
    });
//    Model counter = defineCounter();
//    counter.set({
//        "page": sessionid + "/" + id,
//        "count": 0
//    });
    String page = sessionid + "/" + id;
    con.query("insert into counter (page, count) values(" + page + ", " + 0 + ")");
    if (TRACE_USER) {
        Map m = new Map();
        m["id"] = req.session["id"];
        m["creating"] = codename;
        /*System.ntraceNotice("Aspen:Create", m);*/
    }
    return redirect("/aspen/" + sessionid + "/" + id);
}

HttpResponse delete(HttpRequest req, String[] args)
{
    if (req.session["id"] == null || req.method == "GET") {
        return null;
    }
    HttpResponse res = new HttpResponse();
    res["Content-Type"] = "application/json; charset=utf-8";
    Json j = new Json();
    String id = req.params_post["id"];
    if (id == "" || id == null) {
        j["error"] = true;
        j["message"] = "Invalid id or user.";
        res.content = j.stringify();
        return res;
    }
    Model scripts = defineScripts();
    scripts.remove({
        "user": req.session["id"],
        "id": id
    });
    j["message"] = "Script deleted successfully.";
    res.content = j.stringify();
    if (TRACE_USER) {
        Map m = new Map();
        m["id"] = req.session["id"];
        m["deleting"] = id;
        /*System.ntraceFailed("Aspen:Delete", m);*/
    }
    return res;
}

HttpResponse search(HttpRequest req, String[] args)
{
    if (req.method == "POST") {
        return null;
    }
    Template tpl = getDefaultTemplate(req);
    String searchtext = req.params_get["text"];
    tpl["Search.Text"] = searchtext;
    Array matched_names = [];
    Array matched_scripts = [];
    //Array matched_contents = [];
    if (searchtext != null && searchtext != "") {
        String[] names = User.getList();
        Model scripts = defineScripts();
        foreach (String name in names) {
            /*name = name.convert(to:durl);*/
            if (name.indexOf(searchtext) >= 0) {
                matched_names.add(name);
            }
        }
        Map[] records = scripts.get("user, id, name");
        foreach (Map record in records) {
            record["name"] = (record["name"].toString())/*.convert(to:durl)*/;
            String content = "";
            if (record["name"].indexOf(searchtext) >= 0) {
                record.remove("js");
                matched_scripts.add(record);
            }
        }
        //Map[] records = scripts.get("user, id, name, js");
        //foreach (Map record in records) {
        //    record["name"] = ((to String)record["name"]).convert(to:durl);
        //    String content = "";
        //    if (record["js"] != null) {
        //        content = ((to String)record["js"]).convert(to:durl);
        //        int index = content.indexOf(searchtext);
        //        if (index >= 0) {
        //            if (index <= 30) {
        //                record["js"] = content.substring(0, 120) + " ...";
        //            }
        //            else {
        //                record["js"] = "... " + content.substring(index - 30, 120) + " ...";
        //            }
        //            matched_contents.add(record);
        //        }
        //    }
        //    if (record["name"].indexOf(searchtext) >= 0) {
        //        record.remove("js");
        //        matched_scripts.add(record);
        //    }
        //}
    }
    tpl["Result.Users"] = matched_names;
    tpl["Result.Codes"] = matched_scripts;
    //tpl["Result.Contents"] = matched_contents;
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("search.cs");
    if (TRACE_USER) {
        Map m = new Map();
        m["id"] = req.session["id"];
        m["searching"] = searchtext;
        m["UserNum"] = matched_names.getSize();
        m["CodeNum"] = matched_scripts.getSize();
        /*System.ntraceFailed("Aspen:Search", m);*/
    }
    return new HttpResponse(tpl.render(ctx));
}

HttpResponse inquire(HttpRequest req, String[] args)
{
    if (req.session["id"] == null) {
        return redirect("/aspen/");
    }
    Template tpl = getDefaultTemplate(req);
    if (req.method != "POST") {
        TemplateContext ctx = new TemplateContext();
        ctx.parseFile("inquire.cs");
        return new HttpResponse(tpl.render(ctx));
    }
    Model inquiries = defineInquiries();
    inquiries.set({
        "title": req.params_post["title"]/*.convert(to:url)*/,
        "name": req.session["id"],
        "contents": req.params_post["contents"]/*.convert(to:url)*/,
        "date": new Date().toString();
    });
    return redirect("/aspen/contact/" + inquiries.id);
}

HttpResponse contact(HttpRequest req, String[] args)
{
    if (args[1] == "new") {
        return inquire(req, args);
    }
    Template tpl = getDefaultTemplate(req);
//    Model inquiries = defineInquiries();
    Connection con = new Connection(DBPATH);
    if (args[1].toInt() != 0) {
//        Map[] m = inquiries.get("*", {
//            "id": args[1].toInt()
//        });
        ResultSet r = con.query("select * from inquiries where id=" + args[1].toInt());
        if (r.next() == false) {
            return null;
        }
        Map topic = {};
//        topic["Title"] = (m[0]["title"].toString())/*.convert(to:durl)*/;
//        topic["Name"] = m[0]["name"];
//        topic["Contents"] = (m[0]["contents"].toSting())/*.convert(to:durl)*/;
//        topic["Date"] = m[0]["date"];
        topic["Title"] = r.getString("title");
        topic["Name"] = r.getString("name");
        topic["Contents"] = r.getString("contents");
        topic["Date"] = r.getString("date");
        tpl["Topic"] = topic;
        TemplateContext ctx = new TemplateContext();
        ctx.parseFile("topic.cs");
        return new HttpResponse(tpl.render(ctx));

    }
    Array threadlist = [];
//    foreach (Map m in inquiries.get("id, title, name, date")) {
//        int id = m["id"];
//        String title = (m["title"].toString())/*.convert(to:durl)*/;
//        String name = m["name"];
//        String date = m["date"];
//        threadlist.add({
//            "Id": id.toString(),
//            "Title": title,
//            "Name": name,
//            "Date": date
//        });
//    }
    while (r.next() == true) {
      int id = r.getInt("id");
      String title = r.getString("title");
      String name = r.getString("name");
      String date = r.getString("date");
      threadlist.add({
          "Id": id.toString(),
          "Title": title,
          "Name": name,
          "Date": date
      });
    }
    tpl["Threads"] = threadlist;
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("contact.cs");
    return new HttpResponse(tpl.render(ctx));
}

HttpResponse update(HttpRequest req, String[] args)
{
    if (req.method != "POST" || req.session["id"] == null) {
        return null;
    }
    String update_value = req.params_post["update_value"];
    String script_id = req.params_post["script_id"];
    String original_value = req.params_post["original_value"];
    Json j = new Json();
    if (update_value.trim().getSize() == 0) {
        j["error"] = true;
        j["errormsg"] = "Name is empty.";
        j["value"] = original_value;
        return new HttpResponse(j.stringify());
    }
    else if (update_value.getSize() >= 128) {
        j["error"] = true;
        j["errormsg"] = "Name is too long (should be no longer than 128).";
        j["value"] = original_value;
        return new HttpResponse(j.stringify());
    }
//    Model scripts = defineScripts();
//    scripts.update({"name": update_value.convert(to:url)}, {"user": req.session["id"], "id": script_id});
    Connection con = new Connection(DBPATH);
    con.query("update scripts set name=" + update_value/*.convert(to:url)*/ + " where user=" + req.session["id"] + " and id=" + script_id);
    if (TRACE_USER) {
        Map m = new Map();
        m["id"] = req.session["id"];
        m["script"] = script_id;
        m["oldname"] = original_value;
        m["newname"] = update_value;
        /*System.ntraceNotice("Aspen:Update", m);*/
    }
    j["value"] = update_value;
    return new HttpResponse(j.stringify());
}

//HttpResponse preference(HttpRequest req, String[] args)
//{
//    Template tpl = getDefaultTemplate(req);
//    Model userinfo = defineUserinfo();
//    String userid = req.session["id"];
//    int id = User.getUserId(userid);
//    Map[] m = userinfo.get("email", {"id": id});
//    String email = m[0]["email"];
//    tpl.readFile("setting.hdf");
//    tpl["Form.Inputs.0.Input.Value"] = email;
//    TemplateContext ctx = new TemplateContext();
//    ctx.parseFile("form.cs");
//    return new HttpResponse(tpl.render(ctx));
//}

HttpResponse help(HttpRequest req, String[] args)
{
    Template tpl = getDefaultTemplate(req);
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("help.cs");
    return new HttpResponse(tpl.render(ctx));
}

HttpResponse admintop(HttpRequest req, String[] args)
{
    if (req.session["id"] == null || (!isAdminUser(req.session["id"]))) {
        return redirect("/aspen/");
    }
    Template tpl = getDefaultTemplate(req);
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("admin.cs");
    return new HttpResponse(tpl.render(ctx));
}

HttpResponse copylist(HttpRequest req, String[] args)
{
	if (req.session["id"] == null || (!isAdminUser(req.session["id"]))) {
        return redirect("/aspen/");
    }
    Array codelist = [];
//    Model scripts = defineScripts();
    Connection con = new Connection(DBPATH);
    ResultSet r = con.query("select user, id, name, date");
//    foreach (Map m in scripts.get("user, id, name, date")) {
//        String id = m["id"];
//        String name = m["name"];
//        codelist.add({
//            "User": m["user"],
//            "Id": id,
//            "Name": name/*.convert(to:durl)*/,
//            "Date": m["date"]
//        });
//    }
    while (r.next == true) {
      String id = r.getString("id");
      String name = r.getString("name");
      codelist.add({
          "User": r.getString("user"),
          "Id": id,
          "Name": name/*.convert(to:durl)*/,
          "Date": r.getString("date")
      });
    }
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("copylist.cs");
    Template tpl = getDefaultTemplate(req);
    tpl["Code"] = codelist;
    return new HttpResponse(tpl.render(ctx));
}

HttpResponse console(HttpRequest req, String[] args)
{
    TemplateContext ctx = new TemplateContext("<!DOCTYPE html>\n<html>\n<head>\n<title>JQuery Console Demo</title>\n<script src=\"<?cs var:STATIC_URL ?>/js/libs/jquery-1.7.1.min.js\"></script>\n<script src=\"<?cs var:STATIC_URL ?>/js/libs/jquery.console.js\"></script>\n<script type=\"text/javascript\">\nvar console1;\n$(document).ready(function(){\n/* First console */\nconsole1 = $('.console1');\nvar controller1 = console1.console({\n//promptLabel: 'Demo> ',\ncommandValidate:function(line){\nif (line == "") return false;\nelse return true;\n},\ncommandHandle:function(line){\nreturn [{msg:\"=> [12,42]\",\nclassName:\"jquery-console-message-value\"},\n{msg:\":: [a]\",\nclassName:\"jquery-console-message-type\"}]\n},\nautofocus:true,\nanimateScroll:true,\npromptHistory:true,\ncharInsertTrigger:function(keycode,line){\n// Let you type until you press a-z\n// Never allow zero.\nconsole.log(keycode);\nconsole.log(line);\n//return !line.match(/[a-z]+/) && keycode != '0'.charCodeAt(0);\nreturn true;\n}\n});\n});\n</script>\n<style type=\"text/css\" media=\"screen\">\ndiv.console1 { word-wrap: break-word; }\n/* First console */\ndiv.console1 { font-size: 14px }\ndiv.console1 div.jquery-console-inner\n{ width:900px; height:200px; background:#333; padding:0.5em;\noverflow:auto }\ndiv.console1 div.jquery-console-prompt-box\n{ color:#fff; font-family:monospace; }\ndiv.console1 div.jquery-console-focus span.jquery-console-cursor\n{ background:#fefefe; color:#333; font-weight:bold }\ndiv.console1 div.jquery-console-message-error\n{ color:#ef0505; font-family:sans-serif; font-weight:bold;\npadding:0.1em; }\ndiv.console1 div.jquery-console-message-value\n{ color:#1ad027; font-family:monospace;\npadding:0.1em; }\ndiv.console1 div.jquery-console-message-type\n{ color:#52666f; font-family:monospace;\npadding:0.1em; }\ndiv.console1 span.jquery-console-prompt-label { font-weight:bold }\n</style>\n</head>\n<body>\n<div class=\"console1\"></div>\n</body>\n</html>\n");
    Template tpl = getDefaultTemplate(req);
    return new HttpResponse(tpl.render(ctx));
}

//urlpatterns = [new Tuple(RegExp("^aspen/$"),top), new Tuple(RegExp("^aspen/about/$"),about), new Tuple(RegExp("^aspen/admin/copylist/$"),copylist), new Tuple(RegExp("^aspen/admin/console/$"),console), new Tuple(RegExp("^aspen/admin/$"),admintop), new Tuple(RegExp("^aspen/contact/.*$"),contact), new Tuple(RegExp("^aspen/check/.+$"),check), new Tuple(RegExp("^aspen/help/$"),help), new Tuple(RegExp("^aspen/action/create$"),create), new Tuple(RegExp("^aspen/action/delete$"),delete), new Tuple(RegExp("^aspen/action/login$"),login), new Tuple(RegExp("^aspen/action/logout$"),logout), new Tuple(RegExp("^aspen/action/save$"),save), new Tuple(RegExp("^aspen/action/search$"),search), new Tuple(RegExp("^aspen/action/signup$"),signup), new Tuple(RegExp("^aspen/action/update$"),update), /*new Tuple(RegExp("^aspen/action/setting$"),preference),*/ new Tuple(RegExp("^aspen/.+$"),usertop)];
