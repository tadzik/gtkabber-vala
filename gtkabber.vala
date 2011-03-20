class Gtkabber {
    Gui.Window window       = new Gui.Window();
    Silentear.Client client = new Silentear.Client();

    public Gtkabber() {
        this.client.jid      = "foo@example.com";
        this.client.passwd   = "sikret";
        this.client.resource = "gtkabber-vala";
        this.client.tls      = true;
        this.client.connect();

        this.client.on_connect.connect(() => {
            this.window.log("connected, sending status\n");
            this.client.send_status(
                null, Silentear.Status.DND, "testing, dnd"
            );
        });
        this.client.on_presence.connect((o, p) => {
            this.window.log("Got presence from " + p.from + "\n");
        });
        this.client.roster.contact_updated.connect((o, p) => {
            this.window.log("Got a roster entry: " + p.name + "\n");
        });
    }
}

int main(string[] args) {
    Gtk.init(ref args);
    var app = new Gtkabber();
    Gtk.main();
    return 0;
}
