names = ["john", "bob", "billy", "willy-wanker jorgenson", "jimmy jorgenson"]
puts names.join ", "
puts names.map(&.ends_with?("jorgenson")).join ", " # get all of the jorgensons
puts names[1] # get bob
puts names[0..3] # get john bob and billy
