/**
 * Controller script.
 */

/* It must be called before veins package is loaded. */
import("konoha");
import("konoha.new");
//import("konoha.exception");
import("konoha.regexp");
//import("konoha.sql");
import("posix.fd");
import("posix.file");
import("posix.process");
import("posix.socket");
import("posix.thread");
import("konoha.defined");

load("/home/yoshiaki/eclipse/workspace/Translate/konoha.veins/veins.k");
load("/home/yoshiaki/eclipse/workspace/Translate/Veins.test/settings.k");

HttpResponse document(HttpRequest req, String[] args)
{
    HttpResponse res = new HttpResponse("page '" + args[0] + "', column '" + args[1] + "' document");
    res["Content-Type"] = "text/plain";
    return res;
}

HttpResponse menu(HttpRequest req, String[] args)
{
    Template tpl = new Template();
    tpl.readFile("top.hdf");
    tpl.readFile("menu.hdf");
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("menu.cs");
    HttpResponse res = new HttpResponse(tpl.render(ctx));
    res["Content-Type"] = "text/html";
    return res;
}

HttpResponse session(HttpRequest req, String[] args)
{
    Template tpl = new Template();
    if (req.method == "POST") {
        Map[String] params = req.params_post;
        if (params["type"] == "set") {
            String key = params["key"];
            String value = params["value"];
            if (key != null) {
                req.session[key] = value;
            }
        }
        else if (params["type"] == "remove") {
            String key = params["key"];
            if (key != null) {
                req.session.remove(key);
            }
        }
        else if (params["type"] == "renew") {
            req.session = req.session.renew();
            tpl["Session.ID"] = req.session.fname/*.convert(to:SHA256)*/;
        }
    }
    tpl.readFile("top.hdf");
    if (tpl["Session.ID"] == null) {
        tpl["Session.ID"] = req.session.fname;
    }
    Array items = [];
    foreach (String key in req.session.keys()) {
        items.add({"key": key, "value": req.session[key]});
    }
    tpl["Session.Items"] = items;
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("session.cs");
    HttpResponse res = new HttpResponse(tpl.render(ctx));
    res["Content-Type"] = "text/html";
    return res;
}

HttpResponse top(HttpRequest req, String[] args)
{
    Template tpl = new Template();
    tpl.readFile("top.hdf");
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("top.cs");
    HttpResponse res = new HttpResponse(tpl.render(ctx));
    res["Content-Type"] = "text/html";
    return res;
}

HttpResponse request(HttpRequest req, String[] args)
{
    Template tpl = new Template();
    tpl.readFile("top.hdf");
    Array items = [];
    tpl["method"] = req.method;
    Map[String] params;
    if (req.method == "GET") {
        params = req.params_get;
    }
    else if (req.method == "POST") {
        params = req.params_post;
    }
    foreach (String key in params.keys()) {
        items.add({"key": key, "value": params[key]});
        System.p("key: " + key + "value: " + params[key]);
    }
    tpl["Items"] = items;
    TemplateContext ctx = new TemplateContext();
    ctx.parseFile("request.cs");
    HttpResponse res = new HttpResponse(tpl.render(ctx));
    res["Content-Type"] = "text/html";
    return res;
}

//urlpatterns = [new Tuple(RegExp("^test/$"), top), new Tuple(RegExp("^test/request/$"), request), new Tuple(RegExp("^test/doc/\\w+/\\w+/$"), document), new Tuple(RegExp("^test/menu/\\w+/$"), menu), new Tuple(RegExp("^test/session/$"), session)];
