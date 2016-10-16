/**
 * Copyright Tyto Software Pvt. Ltd.
 */
__sahiDebug__("user_ext.js: start");

/**
 * Copyright Tyto Software Pvt. Ltd.
 */
// you may add your custom global functions here
// uncomment line which includes extensions.js in config/inject_top.txt


//var trace = window.open().document;
//trace.write("title : " + window.document.title + "<br>");
//trace.write("opener : " + window.opener + "<br>");
//trace.write("location.href : " + window.location.href + "<br>");
//trace.write("referrer : " + window.document.referrer + "<br>");
//trace.write("history : " + window.history.entries + "<br>");

/* Pour IE 8 */
if (!String.prototype.trim) {
    String.prototype.trim = function () {
        return this.replace(/^\s+|\s+$/g, '');
    }
}
if (!Array.indexOf) {
    Array.prototype.indexOf = function (obj) {
        for (var i = 0; i < this.length; i++) {
            if (this[i] == obj) {
                return i;
            }
        }
        return -1;
    }
}
/* fin pour IE 8 */

var Uri = function (str) {
    var uri = "",
        o = {
            strictMode: false,
            key: ["source", "protocol", "authority", "userInfo", "user", "password", "host", "port", "relative", "path", "directory", "file", "query", "anchor"],
            q: {
                name: "queryKey",
                parser: /(?:^|&)([^&=]*)=?([^&]*)/g
            },
            parser: {
                strict: /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/,
                loose: /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
            }
        },
        m = o.parser[o.strictMode ? "strict" : "loose"].exec(str),
        uri = {},
        i = 14;

    while (i--) uri[o.key[i]] = m[i] || "";

    uri[o.q.name] = {};
    uri[o.key[12]].replace(o.q.parser, function ($0, $1, $2) {
        if ($1) uri[o.q.name][$1] = $2;
    });


    Uri.prototype.protocol = function () {
        return (uri["protocol"] || "").trim();
    };
    Uri.prototype.path = function () {
        return (uri["path"] || "").trim();
    };
    Uri.prototype.host = function () {
        return (uri["host"] || "").trim();
    };
    Uri.prototype.valid = function () {
        return uri["protocol"] != "" && uri["host"] != "" && uri["path"] != "";
    };
}


/*
 Appuie sur le bouton <back> du navigateur
 */
Sahi.prototype.go_back = function () {
    try {
        window.history.go(-1);
    }
    catch (e) {
        // trace.write("GoBack : " + e.message + "<br>");
    }
};


/* met à jour un attribut d'un balise HTML : target par exemple pour <a>
 a : elementstub html
 b : attribut
 c : value
 appelé par model/browser/driver.rb=> Browsers::Sahi::ElementStub.SetAttributes(attribut, value)
 */
Sahi.prototype.setAttribute = function (a, b, c) {
    if (null == b)return null;
    if (null == c)return null;
    return a.setAttribute(b, c)
};

Sahi.prototype.screenshot_body = function () {

    try {
        //error_label = le texte de l'excetpion si une erreur a été levée
        // 'over' si tout est OK

        var error_label = document.createElement("p");
        error_label.id = "error_label";
        if (document.contains(document.getElementById("error_label"))) {
            document.getElementById("error_label").remove();
        } else {
            document.body.appendChild(error_label);
        }


        //le screenshot encodé en base 64
        var screenshot_base64 = document.createElement("p");
        screenshot_base64.id = "screenshot_base64";
        if (document.contains(document.getElementById("screenshot_base64"))) {
            document.getElementById("screenshot_base64").remove();
        } else {
            document.body.appendChild(screenshot_base64);
        }


        screenshot(document.body)
    }
    catch (e) {
        document.getElementById("error_label").appendChild(document.createTextNode("screenshot_body => " + e));

    }
}

Sahi.prototype.screenshot_element_by_id = function (id) {
    try {
        //error_label = le texte de l'excetpion si une erreur a été levée
        // 'over' si tout est OK
        var error_label = document.createElement("p");
        error_label.id = "error_label";
        if (document.contains(document.getElementById("error_label"))) {
            document.getElementById("error_label").remove();
        } else {
            document.body.appendChild(error_label);
        }


        //le screenshot encodé en base 64
        var screenshot_base64 = document.createElement("p");
        screenshot_base64.id = "screenshot_base64";
        if (document.contains(document.getElementById("screenshot_base64"))) {
            document.getElementById("screenshot_base64").remove();
        } else {
            document.body.appendChild(screenshot_base64);
        }

        var captcha = document.querySelector(id);
        if (isNull(captcha) == true) {
            throw "captcha not found" ;
        }
        else {
            screenshot(captcha);
        }
    }
    catch (e) {
        document.getElementById("error_label").appendChild(document.createTextNode("screenshot_element_by_id => " + e));
    }
}

function screenshot(elt) {
    try {

        html2canvas(elt).then(function (canvas) {
                // html2canvas a fait le screenshot, il est dans le canvas
                try {
                    //à commenter
                    document.body.appendChild(canvas);

                    //encodage du screenshot en base 64, en chaine de caractère pour le retourner
                    var dataURL = canvas.toDataURL("image/png");
                    dataURL = dataURL.replace(/^data:image\/(png|jpg);base64,/, "")

                    //stockage dans la page html, dans l'element 'screenshot_base64'
                    document.getElementById("screenshot_base64").appendChild(document.createTextNode(dataURL));

                    // indique que la capture est terminée
                    document.getElementById("error_label").appendChild(document.createTextNode("over"));
                }
                catch (e) {
                    document.getElementById("error_label").appendChild(document.createTextNode("screenshot 1 => " + e));
                }
            }
        )
        ;
    }

    catch
        (e) {
        document.getElementById("error_label").appendChild(document.createTextNode("screenshot 2 => " + e));
    }
}

/*
 recupere les links (retournés par la méthode document.link ) de la fenetre courante.
 et ds chacune des frames composant la page.
 les link doivent satisfaire certains critères pour être conservés :
 être visible
 scheme : http ou https
 url est différent de l'url de la page courante
 uri est valide
 link a un libelle
 le target ne cree pas une nouvelle fenetre
 les extensions suivantes ne sont pas acceptés  :".css", ".jsp", ".svg", ".gif", ".jpeg", ".jpg", ".png", ".pdf
 */
Sahi.prototype.links = function () {
    //trace = window.open().document;
    try {
        return JSON.stringify({links: links_in_window(window)});
    }
    catch (e) {
        //trace.write("links Exception : " + e.message + "<br>");
        return e;
    }
};

function links_in_window(w) {
    //trace.write("links_in_window debut<br>")
    try {
        var res = new Array(),
            arr_lnks = null;
        if (w !== undefined) {
            if (w.document !== undefined) {
                arr_lnks = links_in_document(w.document);
                for (var i = 0; i < arr_lnks.length; i++) {
                    if (is_selectable(arr_lnks[i], w.location)) {

                        res.push({
                            href: arr_lnks[i].href,
                            target: arr_lnks[i].target,
                            text: encodeURI(arr_lnks[i].textContent || arr_lnks[i].text).replace("'", "&#44;")
                        });

                        //trace.write(arr_lnks[i].href + "<br>");
                    }
                }
                for (var j = 0; j < w.frames.length; j++) {
                    res = res.concat(this.links_in_window(w.frames[j]));
                }
            }
        }
    }
    catch (e) {
        //trace.write("links_in_window Exception " + e.message + "<br>");
    }
    //trace.write("links_in_window fin<br>")
    return res;
}
function links_in_document(d) {
    //trace.write("links_in_document debut<br>");
    var lnks = null;
    try {
        lnks = d.links;
    }
    catch (e) {
        //trace.write("links_in_document exception" + e.message + "<br>");
        lnks = new Array();
    }
    //trace.write("links_in_document fin<br>");
    return lnks;
}
function is_selectable(link, url_window) {
    var href = link.href,
        uri = new Uri(href),
        protocol = uri.protocol(),
        path = uri.path(),
        length = ".svg".length,
        extension = path.substr(path.length - length - 1, length);

    return _sahi._isVisible(link) &&
        (protocol == "http" || protocol == "https") &&
        href != url_window &&
            // href.indexOf(url_window + "#") != 0 && // supprime les lien contenant un lien dans la page au moyen d'une ancre
        uri.valid() == true &&
        link.textContent != "" &&
        (link.target == "_top" || link.target == "_parent" || link.target == "_self" || link.target == "") &&  //on exclue _blank et id car cela cree une nouvelle fenetre
        [".css", ".jsp", ".svg", ".gif", ".jpeg", ".jpg", ".png", ".pdf"].indexOf(extension) < 0 &&  //on exclue ces extension de fichier
        href.slice(-1) != "#"  //on exclue les href qui se terminent par un # car cela est utilisé pour des requetes ajax
}
__sahiDebug__("user_ext.js: end");