/*!
 * Copyright (c) 2018 dreamRs
 *
 * shinylogs, JavaScript bindings to record everything happens in a Shiny app
 * https://github.com/dreamRs/shinylogs
 *
 * @version 0.0.1
 */


$('document').ready(function() {
  // on unload or not
  var logsonunload = false;

  // config
  //$('document').ready(function() {
    var config = document.querySelectorAll('script[data-for="shinylogs"]');
    console.log(config);
    config = JSON.parse(config[0].innerHTML);
    logsonunload = config.logsonunload;
    console.log(logsonunload);
  //});


  // lowdb init
  var adapter = new LocalStorage('db');
  var db = low(adapter);

  // initialize local data storage
  db.defaults({ input: [], error: [], output: [] }).write();

  // Shiny input event to not track
  var dont_track = [".shinylogs_lastinput", ".shinylogs_input", ".shinylogs_error", ".shinylogs_output"];
  var regex_hidden = RegExp('hidden$');

  // Track INPUTS
  $(document).on('shiny:inputchanged', function(event) {
    //console.log(event);
    if (dont_track.indexOf(event.name) == -1 & regex_hidden.test(event.name) === false) {
      //console.log(event);
      var lastInput = {name: event.name, timestamp: event.timeStamp, value: event.value, type: event.inputType};
      db.get('input').push(lastInput).write();
      if (logsonunload === false) {
        Shiny.setInputValue(".shinylogs_lastinput", lastInput, {priority: "event"});
        var input_ = db.get('input').value();
        input_ = JSON.stringify(input_);
        Shiny.setInputValue(".shinylogs_input:parse_log", {inputs: input_}, {priority: "event"});
      }
    }
  });

  // Track ERRORS
  $(document).on("shiny:error", function(event) {
    //console.log(event);
    if (dont_track.indexOf(event.name) == -1) {
      var lastError = {name: event.name, timestamp: event.timeStamp, error: event.error.message};
      db.get('error').push(lastError).write();
      if (logsonunload === false) {
        var error_ = db.get('error').value();
        error_ = JSON.stringify(error_);
        Shiny.setInputValue(".shinylogs_error:parse_log", {errors: error_});
      }
    }
  });

  // Track OUTPUTs
  $(document).on("shiny:value", function(event) {
    //console.log(event);
    var lastOutput = {name: event.name, timestamp: event.timeStamp, binding: event.binding.binding.name};
    db.get('output').push(lastOutput).write();
    if (logsonunload === false) {
      var output_ = db.get('output').value();
      output_ = JSON.stringify(output_);
      Shiny.setInputValue(".shinylogs_output:parse_log", {outputs: output_});
    }
  });


  if (logsonunload === true) {
    window.onbeforeunload = function(e) {

      var e = e || window.event;

      // For IE and Firefox
      if (e) {
        e.returnValue = "Are you sure?";
      }

      var input_ = db.get('input').value();
      input_ = JSON.stringify(input_);
      Shiny.setInputValue(".shinylogs_input:parse_log", {inputs: input_}, {priority: "event"});

      var error_ = db.get('error').value();
      error_ = JSON.stringify(error_);
      Shiny.setInputValue(".shinylogs_error:parse_log", {errors: error_});

      var output_ = db.get('output').value();
      output_ = JSON.stringify(output_);
      Shiny.setInputValue(".shinylogs_output:parse_log", {outputs: output_});

      return "Are you sure?";
    };
  }


});







