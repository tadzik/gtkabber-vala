using GLib;

namespace Silentear {

public enum Status { ONLINE, FFC, AWAY, XA, DND, OFFLINE }
public enum PresenceType { SUBSCRIBE, UNSUBSCRIBE, ERROR }

private string? status_to_string(Status s) {
    string[] foo = { null, "free", "away", "xa", "dnd", null };
    return foo[s];
}

private Status? status_from_string(string x) {
    switch (x[0]) {
        case 'f':
            return Status.FFC;
        case 'a':
            return Status.AWAY;
        case 'x':
            return Status.XA;
        case 'd':
            return Status.DND;
    }
    return null;
}

public class Message : Object {
    public string from;
    public string to;
    public string body;

    public Message(string from, string to, string body) {
        this.from = from;
        this.to   = to;
        this.body = body;
    }
}

public class Presence : Object {
    public PresenceType? type;
    public string        from;
    public Status        status;
    public string        msg;

    public Presence(PresenceType? type, string from,
                    Status? status, string? msg) {
        this.type = type;
        this.from = from;
        this.status = status;
        this.msg = msg;
    }
}

public class Client : Object {
    Lm.Connection   conn;
    public string server   { get; set; }
    public string jid      { get; set; }
    public string username { get; set; }
    public string passwd   { get; set; }
    public string resource { get; set; }
    public int    port     { get; set; default = 0; }
    public int    priority { get; set; default = 10; }
    public bool   ssl      { get; set; default = false; }
    public bool   tls      { get; set; default = false; }
    public Roster roster = new Roster();

    public signal void on_connect();
    public signal void on_message(Message x);
    public signal void on_presence(Presence x);

    public Client() {
        this.notify["ssl"].connect((s, p) => {
            if (this.ssl)
                this.tls = false;
        });
        this.notify["tls"].connect((s, p) => {
            if (this.tls)
                this.ssl = false;
        });
        this.notify["jid"].connect((s, p) => {
            int pos = 0;
            while (jid[pos] != '@') pos++;
            this.username = jid[0:pos];
        });
    }

    private void auth_cb(Lm.Connection c, bool ok) {
        if (!ok) {
            stderr.printf("Auth failed\n");
            return;
        }

        this.conn.register_message_handler(
            new Lm.MessageHandler(presence_cb, null),
            Lm.MessageType.PRESENCE,
            Lm.HandlerPriority.NORMAL
        );
        this.conn.register_message_handler(
            new Lm.MessageHandler(message_cb, null),
            Lm.MessageType.MESSAGE,
            Lm.HandlerPriority.NORMAL
        );
        this.conn.register_message_handler(
            new Lm.MessageHandler(iq_cb, null),
            Lm.MessageType.IQ,
            Lm.HandlerPriority.NORMAL
        );

        try {
            this.conn.send(Roster.request());
        } catch (Error e) {
            stderr.printf("Error sending roster request: %s\n",
                          e.message);
        }
        this.on_connect();
    }

    public new void connect() {
        this.conn = new Lm.Connection(this.server);
        if (this.port == 0) {
            if (this.ssl || this.tls)
                this.port = this.conn.DEFAULT_PORT_SSL;
            else
                this.port = this.conn.DEFAULT_PORT;
        }
        this.conn.set_port(this.port);

        if (this.ssl || this.tls) {
            assert(Lm.SSL.is_supported());
            var ssl = new Lm.SSL("", ssl_cb, null);
            ssl.use_starttls(!this.ssl, this.tls);
            this.conn.set_ssl(ssl);
        }
        this.conn.set_jid(this.jid);
        this.conn.set_keep_alive_rate(30);
        this.conn.set_disconnect_function(disconnect_cb, null);

        try {
            this.conn.open(open_cb, null);
        } catch(Error e) {
            stderr.printf("Opening failed: %s\n", e.message); //XXX
        }
    }

    private void disconnect_cb(Lm.Connection c, Lm.DisconnectReason r) {
        //XXX
        stderr.printf("Disconnected, lol\n");
    }

    private Lm.HandlerResult iq_cb(Lm.MessageHandler h,
                                   Lm.Connection c,
                                   Lm.Message m) {
        var query = m.node.get_child("query");
        if (query != null) {
            if (query.get_attribute("xmlns") == "jabber:iq:roster")
                this.roster.parse_iq(query);
        }
        return Lm.HandlerResult.REMOVE_MESSAGE;
    }

    private Lm.HandlerResult message_cb(Lm.MessageHandler h,
                                        Lm.Connection c,
                                        Lm.Message m) {
        var body = m.node.get_child("body");
        if (body == null) {
            //TODO: that's a funny type of message
            // that we don't handle yet
            return Lm.HandlerResult.REMOVE_MESSAGE;
        }
        var msg = new Message(
            m.node.get_attribute("from"),
            m.node.get_attribute("to"),
            body.value
        );
        on_message(msg);
        return Lm.HandlerResult.REMOVE_MESSAGE;
    }

    private void open_cb(Lm.Connection c, bool ok) {
        if (!ok) {
            stderr.printf("Connection failed\n");
            return;
        }

        try {
            c.authenticate(this.username, this.passwd,
                           this.resource, auth_cb, null);
        } catch(Error e) {
            stderr.printf("Auth failed: %s\n", e.message);
        }
    }

    private Lm.HandlerResult presence_cb(Lm.MessageHandler h,
                                         Lm.Connection c,
                                         Lm.Message m) {
        PresenceType? ptype  = null;
        var type = m.node.get_attribute("type");
        var show = m.node.get_child("show");
        var from = m.node.get_attribute("from");
        var body = m.node.get_child("status");
        var status = (show != null)
                     ? status_from_string(show.value) ?? Status.ONLINE
                     : Status.ONLINE;
        if (type != null) {
            switch (type) {
                case "subscribe":
                    ptype = PresenceType.SUBSCRIBE; break;
                case "unsubscribe":
                    ptype = PresenceType.UNSUBSCRIBE; break;
                case "error":
                    ptype = PresenceType.ERROR; break;
                case "unavailable":
                    status = Status.OFFLINE; break;
            }
        }
        var pres = new Presence(
            ptype,
            from,
            status,
            (body != null) ? body.value : null
        );
        on_presence(pres);
        return Lm.HandlerResult.REMOVE_MESSAGE;
    }

    public void send_status(string? t, Status s, string? m) {
        var msg = new Lm.Message.with_sub_type(
            t,
            Lm.MessageType.PRESENCE,
            (s == Status.OFFLINE) ? Lm.MessageSubType.UNAVAILABLE
                                  : Lm.MessageSubType.AVAILABLE
        );
        msg.node.add_child("priority", this.priority.to_string());

        string? status = status_to_string(s);
        if (status != null)
            msg.node.add_child("show", status);

        if (m != null)
            msg.node.add_child("status", m);

        try {
            this.conn.send(msg);
        } catch(Error e) {
            stderr.printf("Error sending status %s\n", e.message); //XXX
        }
    }

    private Lm.SSLResponse ssl_cb(Lm.SSL ssl, Lm.SSLStatus st) {
        //XXX
        stderr.printf("ssl error: %d\n", st);
        return Lm.SSLResponse.CONTINUE;
    }
}

} // namespace Silentear
