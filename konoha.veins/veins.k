import java.util.Map;

/****************************************************************************
 * KONOHA COPYRIGHT, LICENSE NOTICE, AND DISCRIMER
 *
 * Copyright (c)  2010-      Konoha Team konohaken@googlegroups.com
 * All rights reserved.
 *
 * You may choose one of the following two licenses when you use konoha.
 * See www.konohaware.org/license.html for further information.
 *
 * (1) GNU Lesser General Public License 3.0 (with KONOHA_UNDER_LGPL3)
 * (2) Konoha Software Foundation License 1.0
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 ****************************************************************************/

import("konoha");
import("konoha.new");
import("konoha.exception");
import("konoha.regexp");
import("konoha.sql");
import("jansson");
import("posix.fd");
import("posix.file");
import("posix.process");
import("posix.socket");
import("posix.thread");
import("dscript.logger");
import("libuuid");
const Path = String;

/* ======================================================================== */
/* Utilities. */

@Public String String.escapeHtml()
{
    return this;
}

@Public String String.escapeSql()
{
    if (this.indexOf(";") >= 0) {
        System.throw(new Exception("Invalid sql."));
    }
    return this.replace($/'/, "''").replace($/\\/, "\\\\");
}

/* ======================================================================== */
/* Private methods. */

boolean isDebug()
{
    String debug = DEBUG;
    if (debug == "true" || debug == "on") {
        return true;
    }
    return false;
}

String getDatabase(String dbname)
{
    if (dbname == null) {
        dbname = "default";
    }
    Map dbs = DATABASES;
    if (dbs == null) {
        System.throw(new Exception("DATABASES is null"));
    }
    if (dbs[dbname] == null) {
        if (isDebug()) {
            System.p("DATABASES['" + dbname + "'] is null");
        }
        dbname = "default";
        if (dbs[dbname] == null) {
             System.throw(new Exception("DATABASES['default'] is null"));
        }
    }
    if (dbs[dbname]["name"] == null) {
        System.throw(new Exception("DATABASES['" + dbname + "']['name'] is null"));
    }
    String engine = dbs[dbname]["engine"];
    if (engine == "mysql") {
        String urn = "mysql://" + dbs[dbname]["user"] + ":" + dbs[dbname]["password"];
        urn = url + "@" + dbs[dbname]["host"] + ":" + dbs[dbname]["port"] + "/";
        urn = url + dbs[dbname]["name"];
        if (isDebug()) {
            System.p("urn: " + urn);
        }
        return urn;
    }
    else if (engine == "sqlite3") {
        String urn = "sqlite3:" + dbs[dbname]["name"];
        if (isDebug()) {
            System.p("urn: " + urn);
        }
        return urn;
    }
    System.throw(new Exception("DATABASES['" + engine + "']['engine'] is invalid."));
}

String getMediaDir()
{
    String mediadir = MEDIA_DIR;
    if (mediadir == null) {
        System.throw(new Exception("MEDIA_DIR is null"));
    }
    return mediadir;
}

String getModelDir()
{
    String modeldir = MODEL_DIR;
    if (modeldir == null) {
        System.throw(new Exception("MODEL_DIR is null"));
    }
    return modeldir;
}

String getViewDir()
{
    String viewdir = VIEW_DIR;
    if (viewdir == null) {
        System.throw(new Exception("VIEW_DIR is null"));
    }
    return viewdir;
}

String getTmpDir()
{
    String tmpdir = TMP_DIR;
    if (tmpdir == null) {
        if (isDebug()) {
            System.p("TMP_DIR is null");
        }
        tmpdir = "/tmp/";
    }
    return tmpdir;
}

String getBaseUrl()
{
    String baseurl = BASE_URL;
    if (baseurl == null) {
        System.throw(new Exception("BASE_URL is null"));
    }
    return baseurl;
}

String getStaticUrl()
{
    String staticurl = STATIC_URL;
    if (staticurl == null) {
        System.throw(new Exception("STATIC_URL is null"));
    }
    return staticurl;
}

String[] getMiddlewares()
{
    String[] middlewares = MIDDLEWARES;
    if (middlewares == null) {
        if (isDebug()) {
            System.p("MIDDLEWARES is null");
        }
        middlewares = [];
    }
    return middlewares;
}

String int.escapeSqlValue()
{
        return sql.toString().escapeSql();
}

String Sting.escapeSqlValue()
{
	return "'" + sql.escapeSql() + "'";
}

/* ======================================================================== */
/* Classes. */

class AutoIncrementInt;

class Model
{
    String db_path;
    String name;
    int id;

    boolean isMysql() {
        return db_path.startsWith("mysql");
    }

    Model(String name, Map[String] scheme, String[] primary_keys) {
        name = name.escapeSql();
        this.db_path = getDatabase(name);
        this.name = name;
        String query = "create table if not exists " + name + "(";
        String[] keys = scheme.keys();
        Map[String] types = new Map[String]();
        for (int i = 0; keys.getSize(); i++) {
            String key = keys[i];
            String column = key.escapeSql();
            String type = "";
            String c = scheme.get(key);
            if (c == "String") {
                type = "text";
                types[column] = "text";
            }
            else if (c == "int") {
                type = "integer";
                types[column] = "integer";
            }
            else if (c == "AutoIncrementInt") {
                type = "integer auto_increment";
                types[column] = "integer";
            }
            else {
                System.throw(new Exception("scheme['" + key + "']: Unsupported type is given."));
            }
            if (i < keys.getSize() - 1) {
                query = query + column + " " + type + ", ";
            }
            else {
                query = query + column + " " + type;
                if (primary_keys.getSize() > 0) {
                    query = query + ", primary key(";
                    for (int j = 0; j < primary_keys.getSize(); j++) {
                        String primary_key = primary_keys[j].escapeSql();
                        if (j < primary_keys.getSize() - 1) {
                            if (isMysql() && types[primary_key] == "text") {
                                query = query + primary_key + "(128), ";
                            }
                            else {
                                query = query + primary_key + ", ";
                            }
                        }
                        else {
                            if (isMysql() && types[primary_key] == "text") {
                                query = query + primary_key + "(128))";
                            }
                            else {
                                query = query + primary_key + ")";
                            }
                        }
                    }
                }
                query = query + ")";
            }
        }
        if (isDebug()) {
            System.p("model query: " + query);
        }
        Connection con = new Connection(db_path);
        con.exec(query);
        con.close();
    }

    Map[] get(String column, Map param) {
        column = column.escapeSql();
        String query = "select " + column + " from " + name;
        if (param != null && param.getSize() > 0) {
            query = query + " where ";
            String[] keys = param.keys();
            for (int i = 0; i < keys.getSize(); i++) {
                String key = keys[i];
                String value = escapeSqlValue(param[key]);
                if (i < keys.getSize() - 1) {
                    query = query + key + " = " + value + " and ";
                }
                else {
                    query = query + key + " = " + value;
                }
            }
        }
        if (isDebug()) {
            System.p("get query: " + query);
        }
        Connection con = new Connection(db_path);
        ResultSet r = con.query(query);
        Map[] results = [];
        while (r.next()) {
            Map record = new Map();
            for (int i = 0; i < |r|; i++) {
                String name = r.getName(i);
                if (r[name] != null) {
                    record[name] = r[name];
                }
            }
            if (isDebug()) {
                System.p("record: " + record);
            }
            results.add(record);
        }
        con.close();
        return results;
    }

    void set(Map record) {
        String query;
        if (isMysql()) {
            query = "insert into " + name + "(";
        }
        else {
            query = "insert or replace into " + name + "(";
        }
        String[] values = [];
        String[] keys = record.keys();
        for (int i = 0; i < keys.getSize(); i++) {
            String key = keys[i];
            values.add(escapeSqlValue(record[key]));
            if (i < keys.getSize() - 1) {
                query = query + key.escapeSql() + ", ";
            }
            else {
                query = query + key.escapeSql() + ") values(";
            }
        }
        for (int i = 0; i < values.getSize(); i++) {
            if (i < values.getSize() - 1) {
                query = query + values[i] + ", ";
            }
            else {
                query = query + values[i] + ")";
            }
        }
        if (isMysql()) {
            query = query + " on duplicate key update ";
            for (int i = 0; i < keys.getSize(); i++) {
                if (i < keys.getSize() - 1) {
                    query = query + keys[i] + " = " + values[i] + ", ";
                }
                else {
                    query = query + keys[i] + " = " + values[i];
                }
            }
        }
        if (isDebug()) {
            System.p("set query: " + query);
        }
        Connection con = new Connection(db_path);
        con.exec(query);
        this.id = con.getInsertId();
        con.close();
    }

    void add(Map record) {
        String query = "insert into " + name + "(";
        String[] values = [];
        String[] keys = record.keys();
        for (int i = 0; i < keys.getSize(); i++) {
            String key = keys[i];
            values.add(escapeSqlValue(record.get(key));
            if (i < keys.getSize() - 1) {
                query = query + key.escapeSql() + ", ";
            }
            else {
                query = query + key.escapeSql() + ") values(";
            }
        }
        for (int i = 0; i < values.getSize(); i++) {
            if (i < values.getSize() - 1) {
                query = query + values[i] + ", ";
            }
            else {
                query = query + values[i] + ")";
            }
        }
        if (isDebug()) {
            System.p("add query: " + query);
        }
        Connection con = new Connection(db_path);
        con.exec(query);
        this.id = con.getInsertId();
        con.close();
    }

    void remove(Map record) {
        String query = "delete from " + name + " where ";
        String[] keys = record.keys();
        for (int i = 0; i < keys.getSize(); i++) {
            String key = keys[i];
            if (i < keys.getSize() - 1) {
                query = query + key.escapeSql() + " = " + escapeSqlValue(record.get(key)) + " and ";
            }
            else {
                query = query + key.escapeSql() + " = " + escapeSqlValue(record.get(key));
            }
        }
        if (isDebug()) {
            System.p("remove query: " + query);
        }
        Connection con = new Connection(db_path);
        con.exec(query);
        con.close();
    }

    void update(Map record, Map param) {
        String query = "update " + name + " set ";
        String[] keys = record.keys();
        int i;
        for (i = 0; i < keys.getSize(); i++) {
            String key = keys[i];
            if (i < keys.getSize() - 1) {
                query = query + key.escapeSql() + " = " + escapeSqlValue(record.get(key)) + ", ";
            }
            else {
                query = query + key.escapeSql() + " = " + escapeSqlValue(record.get(key));
            }
        }
        if (param != null && param.getSize() > 0) {
            query = query + " where ";
            keys = param.keys();
            for (i = 0; i < keys.getSize(); i++) {
                String key = keys[i];
                if (i < .keys.getSize() - 1) {
                    query = query + key.escapeSql() + " = " + escapeSqlValue(param.get(key)) + " and ";
                }
                else {
                    query = query + key.escapeSql() + " = " + escapeSqlValue(param.get(key));
                }
            }
        }
        if (isDebug()) {
            System.p("update query: " + query);
        }
        Connection con = new Connection(db_path);
        con.exec(query);
        con.close();
    }
}

/* ------------------------------------------------------------------------ */
/* matsu */

@Singleton class FileStorage
{
    String getRoot() {
        return getMediaDir();
    }

    String checkName(String name) {
        if(name.indexOf("..") != -1) return null;
        Regex r = new Regex("^[\\w_\\.\\-/]+$");
        if(name.search(r) < 0) return null;
        return getMediaDir() + name;
    }

    InputStream open(String name, String mode) {
        name = checkName(name);
        if(name != null) {
            return new InputStream(name, mode);
        }
        return null;
    }

    OutputStream newFile(String name, String mode) {
        name = checkName(name);
        if (isDebug()) {
            System.p("newFile: " + name);
        }
        if(name != null) {
            return new OutputStream(name, mode);
        }
        return null;
    }

    boolean mkdir(String name, int mode) {
        name = checkName(name);
        if (isDebug()) {
            System.p("mkdir: " + name);
        }
        if (name.endsWith("/")) {
            name = name.substring(0, name.getSize() - 1);
        }
        String[] dirnames = name.split("/");
        if (!chdir("/")) {
            return false;
        }
        for (int i = 0; i < dirnames.getSize() - 1; i++) {
            if (dirnames[i] != "" && !chdir(dirnames[i])) {
                return false;
            }
        }
        return System.mkdir(name, mode);
    }
}

class Permission
{
    String name;
    Permission(String name) { this.name = name; }
}

class Group
{
    String name;
    Model group;

    Group(String name) {
        this.name = name;
        this.group = new Model("group_perms", {
            "name": String,
            "permissions": String
        });
    }

    boolean hasPermission(Permission perm) {
        Map[] m = group.get("*", {"name": name});
        if (|m| == 1) {
            String perms = (m[0]["permissions"] == null) ? "" : m[0]["permissions"];
            foreach (String p in perms.split(",")) {
                if (p == perm.name) return true;
            }
        }
        return false;
    }
}

class User
{
    int id;
    String name;
    String[] perms;
    String[] groups;

    User(int id, String name, String[] perms, String[] groups) {
        this.id = id;
        this.name = name;
        this.perms = perms;
        this.groups = groups;
    }

    boolean hasPermission(Permission perm) {
        foreach(String p in perms) {
            if(p == perm.name) return true;
        }
        foreach(String g in groups) {
            if(new Group(g).hasPermission(perm)) return true;
        }
        return false;
    }

    @Static int getUserId(String name) {
        Model user = new Model("users", {
            "id": AutoIncrementInt,
            "name": String,
            "password": String,
            "permissions": String,
            "groups": String
        }, ["id"]);
        Map[] m = user.get("id", {
            "name": name
        });
        int id = -1;
        if (m.getSize() == 1) {
            id = m[0]["id"];
        }
        return id;
    }

    @Static User authenticate(String name, String password) {
        Model user = new Model("users", {
            "id": AutoIncrementInt,
            "name": String,
            "password": String,
            "permissions": String,
            "groups": String
        }, ["id"]);
        Map[] m = user.get("id,permissions,groups", {
            "name": name,
            "password": password.convert(to:SHA256)
        });
        if (|m| == 1) {
            int id = m[0]["id"];
            String[] p;
            String[] g;
            try {
                String perms = m[0]["permissions"];
                p = perms.split(",");
            } catch (Exception e) {
                p = [];
            }
            try {
                String groups = m[0]["groups"];
                g = groups.split(",");
            } catch (Exception e) {
                g = [];
            }
            return new User(id, name, p, g);
        }
        if (isDebug()) {
            System.p("authenticate result: " + m);
        }
        return null;
    }

    @Static boolean hasUser(String name) {
        Model user = new Model("users", {
            "id": AutoIncrementInt,
            "name": String,
            "password": String,
            "permissions": String,
            "groups": String
        }, ["id"]);
        Map[] m = user.get("id", {
            "name": name
        });
        if (m.getSize() == 1) {
            if (isDebug()) {
                System.p("user '" + name + "' exists");
            }
            return true;
        }
        if (isDebug()) {
            System.p("user '" + name + "' does not exist");
        }
        return false;
    }

    @Static User addUser(String name, String password) {
        if (User.hasUser(name)) {
            return null;
        }
        Model user = new Model("users", {
            "id": AutoIncrementInt,
            "name": String,
            "password": String,
            "permissions": String,
            "groups": String
        }, ["id"]);
        user.add({
            "name": name,
            "password": password.convert(to:SHA256)
        });
        return new User(user.id, name, [], []);
    }

    @Static String[] getList() {
        Model user = new Model("users", {
            "id": AutoIncrementInt,
            "name": String,
            "password": String,
            "permissions": String,
            "groups": String
        }, ["id"]);
        Map[] maps = user.get("name");
        String[] list = [];
        foreach (Map m in maps) {
            list.add(m["name"]);
        }
        return list;
    }
}

/* ------------------------------------------------------------------------ */

class TemplateContext
{
    /*Cs cs;*/
    String str;
    Path file;

    TemplateContext(String context) {
        this.str = context;
    }

    void parseFile(Path path) {
        if (!path.startsWith("/")) {
            path = getViewDir() + path;
        }
        this.file = path;
    }

/*    void loadSettingValues(Hdf hdf) {
        hdf.setValue("STATIC_URL", getStaticUrl());
        hdf.setValue("BASE_URL", getBaseUrl());
        hdf.setValue("hdf.loadpaths.0", getViewDir());
        hdf.setValue("hdf.loadpaths.1", getModelDir());
    }*/

/*    void loadHdf(Hdf hdf) {
        loadSettingValues(hdf);
        if (isDebug()) {
            hdf.writeFile("/tmp/hdf");
        }
        this.cs = new Cs(hdf);
        if (str != null) {
            cs.parseString(str);
        }
        if (file != null) {
            cs.parseFile(file);
        }
    }*/
}

class Template
{
    /*Hdf hdf;*/
    String buf;

    Template(String template) {
/*        this.hdf = new Hdf();
        if (template != null) {
            hdf.readString(template);
        }*/
    }
    
    void set(String key, int value) {
    	/*hdf.setIntValue(key, value);*/
    }
    
    void set(String key, String value) {
    	/*hdf.setValue(key, value.escapeHtml());*/
    }
    
    void set(String key, Array value) {
        int i = 0;
        for (; i < value.getSize(); i++) {
            this[key + "." + i.toString()] = value[i];
        }
    }
    
    void set(String key, Map value) {
        String[] mkeys = value.keys();
        for (int i = 0; i < mkeys.getSize(); i++) {
            this[key + "." + mkeys[i]] = value[mkeys[i]];
        }
    }

    int getInt(String key) {
        return 1/*hdf.getIntValue(key)*/;
    }

    String get(String key) {
        return ""/*hdf.getValue(key)*/;
    }

    void readFile(Path path) {
        if (!path.startsWith("/")) {
            path = getModelDir() + path;
        }
        /*hdf.readFile(path);*/
    }

    void readString(String s) {
        /*hdf.readString(s);*/
    }

    int render_cb(String s) {
        this.buf = buf + s;
        return 1/*Cs.STATUS_OK*/;
    }

    String render(TemplateContext context) {
        this.buf = "";
        /*context.loadHdf(hdf);
        context.cs.render(delegate(this, render_cb));*/
        return buf;
    }

    boolean save(String name) {
        String path = FileStorage.checkName(name);
        if (path == null) return false;
        /*hdf.writeFileAtomic(path)*/;
        return true;
    }

    boolean load(String name) {
        String path = FileStorage.checkName(name);
        if (path == null) return false;
        if (System.stat(path) == null) {
            return false;
        }
        /*hdf.readFile(path);*/
        return true;
    }
}

@Expando class HttpRequest //TODO Expand
{
    String path;
    String method;
    Map[String] params_get;
    Map[String] params_post;
    Map[String] cookies;

    HttpRequest(String path, String method, String query, String cookie) {
        this.path = path;
        this.method = method;
        Map[String] m = new Map[String]();
        foreach (String param in query.split("&")) {
            String[] k_v = param.split("=");
            if (k_v.getSize() == 2 && k_v[1] != null) {
                m[k_v[0]] = k_v[1]/*.convert(to:durl)*/;
            }
            else {
                m[k_v[0]] = "";
            }
        }
        if (method == "GET") {
            this.params_get = m;
        }
        else if (method == "POST") {
            this.params_post = m;
        }
        m = new Map[String]();
        if (cookie != null) {
            foreach (String ck in cookie.replace($/ /, "").split(";")) {
                String[] k_v = ck.split("=");
                m[k_v[0]] = k_v[1];
            }
        }
        this.cookies = m;
    }
}

class HttpResponse
{
    String content;
    int status;
    Tuple[String,String][] h;

    HttpResponse(String content, Tuple[String,String][] headers) {
        this.content = content;
        this.h = headers;
        if (h == null) {
            this.h = [];
        }
    }

    void set(String header, String value) {
        h.add((header, value));
    }

    String[] get(String header) {
        String[] ret = [];
        foreach (Tuple[String,String] t in this.h) {
            if (t[0] == header) {
                ret.add(t[1]);
            }
        }
        return ret;
    }

    String[] keys(void) {
        String[] keys = [];
        foreach (Tuple[String,String] t in this.h) {
            if (!((t[0] in? keys))) {
                keys.add(t[0]);
            }
        }
        return keys;
    }

    void setCookie(String key, String value, String expires, String path) {
        path = (path == null) ? "/" : path;
        String cookie = key + "=" + value + "; ";
        if (expires != null && expires != "") {
            cookie = cookie + "expires=" + expires + "; ";
        }
        cookie = cookie + "path=" + path + ";";
        this["Set-Cookie"] = cookie;
        if (isDebug()) {
            System.p("Set-Cookie: " + cookie);
        }
    }

    void deleteCookie(String key, String path) {
        path = (path == null) ? "/" : path;
        String cookie = key + "=dummy; ";
        Date past = new Date();
        past.setYear(1970);
        cookie = cookie + "expires=" + past.toUTCString();
        this["Set-Cookie"] = cookie;
        if (isDebug()) {
            System.p("Delete-Cookie: " + cookie);
        }
    }
}

class HttpResponseRedirect extends HttpResponse
{
    HttpResponseRedirect(String location) {
        this.h = [("Location", location)];
        this.status = 302;
    }
}

@Singleton class Url
{
    Tuple[Regex,Func[HttpRequest,HttpResponse,String[]]][] getPatterns() {
    	Tuple[Regex,Func[HttpRequest,HttpResponse,String[]]][] patterns = VEINS.urlpatterns;
        if (patterns == null) {
        	VEINS.urlpatterns = new Tuple[Regex,Func[HttpRequest,HttpResponse,String[]]][0];
        }
        return VEINS.urlpatterns;
    }

    void setPatterns(Tuple[Regex,Func[HttpRequest,HttpResponse,String[]]][] patterns) {
    	VEINS.urlpatterns = patterns;
    }
}

@Singleton class Middleware
{
    @Virtual HttpResponse hookRequest(HttpRequest req);
    @Virtual HttpResponse hookHandler(HttpRequest req,
            Func[HttpRequest,HttpResponse,String[]] callback, String[] args);
    @Virtual HttpResponse hookResponse(HttpRequest req, HttpResponse res);
    @Virtual HttpResponse hookException(HttpRequest req, Exception e);
}

class Session
{
    Path path;
    String fname;
    String origname;
    Json j;

    Session(String name) {
        if (name != null && name != "") {
            this.origname = name;
            this.fname = name/*.convert(to:SHA256)*/;
        }
        else {
            this.origname = Uuid.getUuid4(); //TODO Uuid
            this.fname = origname/*.convert(to:SHA256)*/;
        }
        this.path = getTmpDir() + fname;
        if (load()) {
            if (isDebug()) {
                System.p("load succeeded");
            }
        }
        else {
            if (isDebug()) {
                System.p("load failed");
            }
        }
    }

    Session renew(String name) {
        if (System.unlink(path)) {
            if (isDebug()) {
                System.p("unlink: " + path);
            }
        }
        else {
            if (isDebug()) {
                System.p("unlink failed: " + path);
            }
        }
        return new Session(name);
    }

    boolean load() {
        if (System.stat(path)== null) {
            this.j = new Json();
            return false;
        }
        else {
            InputStream ins = new InputStream(path);
            this.j = Json.parse(ins.read()/*.decode(to:xor)*/);
            ins.close();
            return true;
        }
    }

    dynamic get(String key) {
        return j[key];
    }

    String[] keys() {
        return j.getKeys();
    }

    void remove(String key) {
        j.delete(key);
    }

    String toString() {
        return j.stringify();
    }
    
    void set(String key, String val) {
    	j[key] = val;
    }
    
    void set(String key, int val) {
    	j[key] = val;
    }
    
    void set(String key, float val) {
    	j[key] = val;
    }

    void store() {
        OutputStream ous = new OutputStream(path);
        ous.write(j.stringify()/*.encode(to:xor)*/);
        ous.close();
    }
}


/* ======================================================================== */
/* Builtin middlwares. */

@Singleton class SessionMiddleware extends Middleware
{
    HttpResponse hookRequest(HttpRequest req) {
        if (isDebug()) {
            System.p("hook request: " + req);
        }
        if (req.cookies["KSESSIONID"] != null) {
            if (isDebug()) {
                System.p("KSESSIONID: " + req.cookies["KSESSIONID"]);
            }
            req.session = new Session(req.cookies["KSESSIONID"]);
        }
        else {
            req.session = new Session();
        }
        return null;
    }

    HttpResponse hookHandler(HttpRequest req,
    		Func[HttpResponse,HttpRequest,String[]] callback, String[] args) {
        if (isDebug()) {
            System.p("hook handler: " + req + callback + args);
        }
        return null;
    }

    HttpResponse hookResponse(HttpRequest req, HttpResponse res) {
        if (isDebug()) {
            System.p("hook response");
        }
        if (req.cookies["KSESSIONID"] == null ||
                req.cookies["KSESSIONID"] != req.session.origname) {
            if (isDebug()) {
                System.p("old session: " + req.cookies["KSESSIONID"]);
                System.p("new session: " + req.session.fname/*.convert(to:SHA256)*/);
            }
            //Date now = new Date();
            //if (now.day < 15) {
            //    now.day += 14;
            //}
            //else if (now.month < 12) {
            //    now.day -= 14;
            //    now.month += 1;
            //}
            //else {
            //    now.year += 1;
            //    now.day -= 14;
            //    now.month -= 11;
            //}
            //res.setCookie("KSESSIONID", req.session.fname, now.toRFC1123());
            res.setCookie("KSESSIONID", req.session.origname);
        }
        req.session.store();
        req.session = null;
        return res;
    }

    HttpResponse hookException(HttpRequest req, Exception e) {
        if (isDebug()) {
            System.p("hook exception: " + req + e);
        }
        return null;
    }
}

@Singleton class LoggingMiddleware extends Middleware
{
    HttpResponse hookRequest(HttpRequest req) {
        Map m = new Map();
        m["path"] = req.path;
        m["method"] = req.method;
        try {
            if (req.session != null) {
                m["session"] = req.session.toString();
            }
        } catch (Exception!! e) {
            m["session"] = "none";
        }
        /*System.ntraceNotice("Veins:Request", m);*/
        return null;
    }

    HttpResponse hookHandler(HttpRequest req,
    		Func[HttpResponse,HttpRequest,String[]]] callback, String[] args) {
        Map m = new Map();
        m["handler"] = callback.name;
        String argstr = "[";
        foreach (String arg in args) {
            argstr = argstr + arg + ",";
        }
        argstr = argstr + "]";
        m["args"] = argstr;
        /*System.ntraceNotice("Veins:Handler", m);*/
        return null;
    }

    HttpResponse hookResponse(HttpRequest req, HttpResponse res) {
        Map m = new Map();
        m["status"] = (res.status == 0) ? 200 : res.status;
        foreach (String h in res.keys()) {
            for (int i = 0; i < res[h].getSize(); i++) {
                String key = "header:" + h + "+" + i.toString();
                m[key] = res[h][i];
            }
        }
        /*System.ntraceNotice("Veins:Response", m);*/
        return res;
    }

    HttpResponse hookException(HttpRequest req, Exception e) {
        Map m = new Map();
        m["message"] = e.toString();
        /*System.ntraceFailed("Veins:Exception", m);*/
        return null;
    }
}

/* ======================================================================== */

HttpRequest g_req;
HttpResponse g_res;
Func[HttpResponse,HttpRequest,String[]]] g_handler;
String[] g_args;
Exception g_e;

@Public String Wsgi.application(Map[String] environ,
        Func[String,Tuple[String,String][]] start_response)
{
    // initialize global variables
    g_req = null;
    g_res = null;
    g_handler = null;
    g_args = null;
    g_e = null;

    String[] middlewares = getMiddlewares();
    String path = environ["URI"];
    if (path.getSize() >= 1 && path != "/") {
        path = path.substring(1);
    }
    if (isDebug()) {
        foreach (String e in environ.keys()) {
            System.p("env[" + e + "]=" + environ[e]);
        }
        System.p("path: " + path);
    }
    try {
        String method = environ["REQUEST_METHOD"];
        String query = environ["QUERY_STRING"];
        String cookie = environ["Cookie"];
        g_req = new HttpRequest(path, method, query, cookie);
        foreach (String middleware in middlewares) {
            if (isDebug()) {
                System.p("call " + middleware + ".hookRequest()");
            }
            eval("g_res = " + middleware + ".hookRequest(g_req);");
            if (g_res != null) {
                break;
            }
        }
        if (g_res == null) {
            foreach (Tuple[Regex,Func[HttpRequest,HttpResponse,String[]]] t in Url.getPatterns()) {
                if (path.search(t[0]) >= 0) {
                    g_args = path.split("/");
                    if (g_args.getSize() > 0) {
                        g_args.remove(0);
                    }
                    g_handler = t[1];
                    if (isDebug()) {
                        System.p("handler: " + g_handler);
                        System.getOut().print("args: [");
                        foreach (String g_arg in g_args) {
                        	System.getOut().print(g_arg + ", ");
                        }
                        System.p("]");
                    }
                    foreach (String middleware in middlewares) {
                        if (isDebug()) {
                            System.p("call " + middleware + ".hookHandler()");
                        }
                        eval("g_res = " + middleware + ".hookHandler(g_req, g_handler, g_args);");
                    }
                    if (g_res != null) {
                        break;
                    }
                    g_res = g_handler(g_req, g_args);
                    break;
                }
            }
        }
        if (g_res != null) {
            foreach (String middleware in middlewares) {
                if (isDebug()) {
                    System.p("call " + middleware + ".hookResponse()");
                }
                eval("g_res = " + middleware + ".hookResponse(g_req, g_res);");
            }
        }
    } catch (Exception e) {
        g_e = e;
        foreach (String middleware in middlewares) {
            if (isDebug()) {
                System.p("call " + middleware + ".hookException()");
            }
            eval("g_res = " + middleware + ".hookException(g_req, g_e);");
            if (g_res != null) {
                break;
            }
        }
    }
    if (g_res != null) {
        Tuple[String,String][] headers = g_res.h;
        if (!("Content-Type" in? g_res.keys())) {
            headers.add(("Content-Type", "text/html; charset=UTF-8"));
        }
        String status = "";
        if (g_res.status == 301) {
            status = "301 Moved Permanently";
        }
        else if (g_res.status == 302) {
            status = "302 Found";
        }
        else if (g_res.status == 404) {
            status = "404 Not Found";
        }
        else {
            status = "200 OK";
        }
        start_response(status, headers);
        return g_res.content;
    }
    if (!(path.endsWith("/"))) {
        String redirect_url = environ["URI"] + "/";
        start_response("302 Found", [
            ("Content-Type", "text/html; charset=UTF-8"),
            ("Location", redirect_url)
        ]);
        return "";
    }
    start_response("404 Not Found", [("Content-Type", "text/html; charset=UTF-8")]);
    return "";
}

class Tuple {
	Array[String] base;
	Tuple(String a, String b) {
		base = [a, b];
	}
	String get(int index) {
		if(index == 0) {
			return base[0];
		}
		else if(index == 1) {
			return base[1];
		}
		return null;
	}
}

String InputStream.read() {
	String ret = "";
	String s = this.readLine();
	while(s != null) {
		ret = ret + s + "\n";
		s = this.readLine();
	}
	return ret;
}
