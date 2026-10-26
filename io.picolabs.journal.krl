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

    
    /**
     * One journal entry by title, or all entries if no title is given. Each entry
     * has timestamp, title, and content.
     * @param title String "entry title; omit for all"
     * @returns Any
     * @example "all" {}
     * @example "one" { "title": "<title>" }
     */
    getEntry = function(title = null) {
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
    // Discovery bindings come from this ruleset's /** */ annotations (pico-engine 1.8+).
    bindings = function() {
      wrangler:schemaBindings(meta:rid)
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
  
  
  /**
   * Add a journal entry to this thing. Its timestamp (when it was added) is its id
   * for edit_entry and delete_entry.
   * @attr title String
   * @attr content String "the note"
   * @example "note" { "title": "<title>", "content": "<text>" }
   */
  rule new_entry {
    select when journal new_entry
    
    pre {
      entry = { "timestamp" : time:now(), "title" : event:attr("title"), "content" : event:attr("content") }
    }
    
    always {
      ent:entries := ent:entries.defaultsTo([]).append(entry);
    }
    
  }
  
  /**
   * Delete a journal entry. Does nothing if no entry has that timestamp.
   * @attr timestamp String "the entry's timestamp (from getEntry)"
   */
  rule delete_entry {
    select when journal delete_entry
    
    pre {
      timestamp = event:attr("timestamp");
      toDeleteIndex = ent:entries.defaultsTo([])
        .map(function(x) { x{"timestamp"} })
        .index(timestamp);
    }
    
    if toDeleteIndex >= 0 then noop();
    
    fired {
      ent:entries := ent:entries.splice(toDeleteIndex, 1);
    }
    
  }
  
  /**
   * Replace a journal entry's content. Does nothing if no entry has that timestamp.
   * @attr timestamp String "the entry's timestamp (from getEntry)"
   * @attr newContent String
   */
  rule edit_entry {
    select when journal edit_entry
    
    pre {
      newContent = event:attr("newContent");
      timestamp = event:attr("timestamp");
      found = ent:entries.defaultsTo([]).any(function(x) {
        x{"timestamp"} == timestamp
      });
    }
    
    if found then noop();
    
    fired {
      ent:entries := ent:entries.map(function(x) {
        (x{"timestamp"} == timestamp) => x.put("content", newContent) | x
      })
    }
    
  }
  
  
}
