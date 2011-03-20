using GLib;

namespace Silentear {

public enum Subscription { TO, FROM, BOTH, NONE }

private Subscription? subscription_from_string(string x) {
    switch(x[0]) {
        case 'b':
            return Subscription.BOTH;
        case 't':
            return Subscription.TO;
        case 'f':
            return Subscription.FROM;
        case 'n':
            return Subscription.NONE;
    }
    return null;
}

public class Contact {
    public string       jid;
    public string       name;
    public string       group; //TODO: we should support multiple groups
    public Subscription subscription;
    public string[]     resources; //TODO: string is not enough
}

public class Roster {
    private HashTable<string, Contact>
        hash = new HashTable<string, Contact>(str_hash, str_equal);

    public signal void contact_updated(Contact c);

    public static Lm.Message request() {
        var req = new Lm.Message.with_sub_type(null, Lm.MessageType.IQ,
                                               Lm.MessageSubType.GET);
        var query = req.node.add_child("query", null);
        query.set_attributes("xmlns", "jabber:iq:roster", null);
        return req;
    }

    public void parse_iq(Lm.MessageNode m) {
        for (var item = m.get_child("item");
             item != null; item = item.next) {
            var entry = new Contact();
            if (item.get_attribute("subscription") == "remove") {
                //TODO: Remove from the hashtable and stuff
                continue;
            }

            entry.jid = item.get_attribute("jid");
            var attr = item.get_attribute("name");
            if (attr != null) {
                entry.name = attr;
            } else {
                int pos = 0;
                while (entry.jid[pos] != '@') pos++;
                entry.name = entry.jid[0:pos];
            }

            attr = item.get_attribute("subscription");
            var sub = subscription_from_string(attr);
            if (sub != null) {
                entry.subscription = sub;
            } else {
                stderr.printf("Unknown subscription type: %s\n", attr);
                continue;
            }

            var node = item.get_child("group");
            if (node != null)
                entry.group = node.value;
            
            hash.insert(entry.jid, entry);
            contact_updated(entry);
        }
    }
}

} // namespace Silentear
