ruleset io.picolabs.journal {
  meta {
    name "Journal"
    description <<
      Attach notes to a Manifold thing. Each entry has a title and body text;
      use this to record maintenance history, packing lists, or anything else
      you want to keep with the thing.
    >>
    author "Pico Labs"

    shares getEntry
    use module io.picolabs.wrangler alias wrangler
  }
  
  global {

    
    getEntry = function(title) {
      (title) => ent:entries.filter(function(x){
        x{"title"} == title
      })[0] | ent:entries;
    }
    
    app = {
      "name": "journal",
      "title": "Journal",
      "version": "0.0",
      "description": "Attach notes to this thing (title + content entries)."
    };
    bindings = function() {
      return {
        "version": 1,
        "queries": [
          {
            "name": "getEntry",
            "args": ["title"],
            "description": "Return one entry by title, or all entries when title is omitted."
          }
        ],
        "events": [
          {
            "domain": "journal",
            "name": "new_entry",
            "attrs": ["title", "content"],
            "description": "Add a note to this thing."
          },
          {
            "domain": "journal",
            "name": "delete_entry",
            "attrs": ["timestamp"],
            "description": "Remove a note by its entry timestamp."
          },
          {
            "domain": "journal",
            "name": "edit_entry",
            "attrs": ["newContent", "timestamp"],
            "description": "Change the body text of an existing note."
          }
        ]
      }
    }
    
  }
  
  // icon image from https://image.flaticon.com/icons/svg/201/201642.svg
  rule discovery {
    select when discovery capabilities
    send_directive("discovery capability", {
      "app": app,
      "rid": meta:rid,
      "bindings": wrangler:filterBindingsForCaller(bindings(), event:attr("eci"), meta:rid),
      "iconURL": "https://raw.githubusercontent.com/Picolab/JournalApp/master/logo.svg"
    });
  }
  
  
  rule new_entry {
    select when journal new_entry
    
    pre {
      entry = { "timestamp" : time:now(), "title" : event:attr("title"), "content" : event:attr("content") }
    }
    
    always {
      ent:entries := ent:entries.defaultsTo([]).append(entry);
    }
    
  }
  
  rule delete_entry {
    select when journal delete_entry
    
    pre {
      timestamp = event:attr("timestamp");
      toDelete = ent:entries.filter(function(x) {
        x{"timestamp"} == timestamp
      })[0];
      toDeleteIndex = ent:entries.index(toDelete);
    }
    
    if (toDelete == -1) then noop();
    
    notfired {
      ent:entries := ent:entries.defaultsTo([]).splice(toDeleteIndex, 1);
    }
    
  }
  
  rule edit_entry {
    select when journal edit_entry
    
    pre {
      newContent = event:attr("newContent");
      timestamp = event:attr("timestamp");
      toChange = ent:entries.filter(function(x) {
        x{"timestamp"} == timestamp
      })[0];
    }
    
    if (toChange == -1) then noop();
    
    notfired {
      ent:entries := ent:entries.defaultsTo([]).map(function(x){
        (x == toChange) => x.put("content", newContent) | x;
      })
    }
    
  }
  
  
}
