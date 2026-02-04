ruleset io.picolabs.journal {
  meta {
    shares getEntry
  }
  
  global {

    
    getEntry = function(title) {
      (title) => ent:entries.filter(function(x){
        x{"title"} == title
      })[0] | ent:entries;
    }
    
    app = {"name":"journal","version":"0.0"/* img: , pre: , ..*/};
    bindings = function(){
      {
        //currently no bindings
      };
    }
    
  }
  
  // icon image from https://image.flaticon.com/icons/svg/201/201642.svg
  rule discovery { select when manifold apps send_directive("app discovered...", {"app": app, "rid": meta:rid, "bindings": bindings(), "iconURL": "https://raw.githubusercontent.com/Picolab/JournalApp/master/logo.svg"} ); }
  
  
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
