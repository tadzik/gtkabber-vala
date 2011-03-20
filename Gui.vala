using GLib;

namespace Gui {

public class Window : Object {
    private Gtk.Notebook nbook;
    private Gui.Roster   roster;
    private Gtk.VBox     toolbox;
    private Gtk.Window   window;
    private Gui.Tab      status_tab;
    public Window() {
        this.nbook   = new Gtk.Notebook();
        this.roster  = new Roster();
        this.toolbox = new Gtk.VBox(false, 0);
        this.window  = new Gtk.Window(Gtk.WindowType.TOPLEVEL);

        var hpaned      = new Gtk.HPaned();
        var leftbox     = new Gtk.VBox(false, 0);
        var scrolled    = new Gtk.ScrolledWindow(null, null);
        var vbox        = new Gtk.VBox(false, 0);
        var statusbox   = new Statusbox();
        var statusentry = new Gtk.Entry();

        window.set_title("gtkabber");
        window.add(vbox);

        vbox.add(hpaned);
        vbox.add(toolbox);

        hpaned.add1(leftbox);
        scrolled.add_with_viewport(roster);
        leftbox.add(scrolled);
        leftbox.add(statusbox);
        leftbox.add(statusentry);

        hpaned.add2(nbook);
        this.status_tab = new Tab(null, "Status", true);
        this.status_tab.add_to_notebook(nbook);

        leftbox.set_child_packing(statusbox, false, false, 0,
                      Gtk.PackType.START);
        leftbox.set_child_packing(statusentry, false, false, 0,
                      Gtk.PackType.START);

        vbox.set_child_packing(toolbox, false, false, 0,
                       Gtk.PackType.START);

        //TODO: It should also close xmpp and stuff
        window.destroy.connect(Gtk.main_quit);
        //statusentry.activate.connect(Xmpp.set_status)
        //window.key-press-event.connect(keypress_cb)
        //window.focus-in-event.connect(focus_cb)
        //nbook.switch-page.connect(or other signal)

        window.show_all();
    }

    public void log(string what) {
        this.status_tab.append_text(what);
    }
}

private class Roster : Gtk.TreeView {
    private enum cols {
        COL_STATUS,
        COL_NAME,
        NUM_COLS
    }
    Gtk.TreeSelection sel;
    Gtk.TreeStore store;
    Gtk.TreeModelFilter filter;
    public Roster () {
        store = new Gtk.TreeStore(cols.NUM_COLS, typeof(Gdk.Pixbuf), typeof(string));

        filter = new Gtk.TreeModelFilter(store, null);
        filter.set_visible_func(filter_func);

        var trend = new Gtk.CellRendererText();
        var prend = new Gtk.CellRendererPixbuf();
        this.insert_column_with_attributes(-1, null, prend, "pixbuf", cols.COL_STATUS);
        this.insert_column_with_attributes(-1, null, trend, "text", cols.COL_NAME);
        this.set_headers_visible(false);

        sel = this.get_selection();
        sel.set_mode(Gtk.SelectionMode.SINGLE);

        //TODO: Load iconset

        store.set_sort_func(cols.COL_STATUS, sort_func);
        store.set_sort_column_id(cols.COL_STATUS, Gtk.SortType.ASCENDING);
        //this.row-activated.connect(blah blah blah)
    }

    private bool filter_func(Gtk.TreeModel m, Gtk.TreeIter iter) {
        //No filtering so far. TODO
        return true;
    }
    private int sort_func(Gtk.TreeModel m, Gtk.TreeIter a, Gtk.TreeIter b) {
        //TODO
        return 0;
    }
}

private class Statusbox : Gtk.ComboBox {
    public Statusbox() {
        Gtk.TreeIter iter;

        var store = new Gtk.ListStore(1, typeof(string));
        store.append(out iter);
        store.set(iter, 0, "Free for chat");
        store.append(out iter);
        store.set(iter, 0, "Online");
        store.append(out iter);
        store.set(iter, 0, "Away");
        store.append(out iter);
        store.set(iter, 0, "Not available");
        store.append(out iter);
        store.set(iter, 0, "Do not disturb");
        store.append(out iter);
        store.set(iter, 0, "Offline");
        this.set_model(store);

        var cell = new Gtk.CellRendererText();
        this.pack_start(cell, true);
        this.set_attributes(cell, "text", 0);

        this.set_active(1);
        /* TODO: Callback for "changed" signal
         * statusbox.changed.connect(and some lambda here maybe)
         * also, we can connect it to Xmpp "status_changed signal"
         * or something like this. */
    }
}

private class MLEntry : Gtk.TextView {
    //TODO
}

private class Tab : Object {
    Silentear.Contact? who;
    Gtk.TextBuffer     buffer;
    Gtk.TextMark       mark;
    Gui.MLEntry        entry;
    Gtk.Label          label;
    Gtk.EventBox       evbox;
    Gtk.ScrolledWindow scrolled;
    Gtk.TextView       textview;
    Gtk.VPaned         vbox;

    public Tab(Silentear.Contact? who, string? title, bool active) {
        title = title ?? who.name;
        this.who = who;

        this.evbox = new Gtk.EventBox();
        this.evbox.set_visible_window(false);
        this.label = new Gtk.Label(title);
        this.evbox.add(label);
        label.show();
        //evbox.button_press_event.connect()
        this.textview = new Gtk.TextView();
        this.buffer   = this.textview.get_buffer();
        this.textview.set_editable(false);
        this.textview.set_cursor_visible(false);
        this.textview.set_wrap_mode(Gtk.WrapMode.WORD);
        this.mark     = this.buffer.get_mark("insert");
        this.scrolled = new Gtk.ScrolledWindow(null, null);
        this.scrolled.set_policy(Gtk.PolicyType.AUTOMATIC,
                                 Gtk.PolicyType.AUTOMATIC);
        this.scrolled.add_with_viewport(this.textview);
        if (who != null) {
            this.entry = new MLEntry();
            //XXX set_wrap_mode and stuff
        }
        this.vbox = new Gtk.VPaned();
        this.vbox.pack1(this.scrolled, true, false);
        if (who != null) {
            this.vbox.pack2(this.entry, true, false);
        }
        this.vbox.show_all();
    }

    public void add_to_notebook(Gtk.Notebook nb) {
        nb.append_page(this.vbox, this.evbox);
    }

    public void append_text(string what) {
        Gtk.TextIter i;
        this.buffer.get_end_iter(out i);
        this.buffer.insert(i, what, (int)what.len());
    }
}

} // namespace Gui
