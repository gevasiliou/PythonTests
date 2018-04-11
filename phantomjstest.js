var page = require('webpage').create();
page.open('https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=732209', function(status) {
  console.log("Status: " + status);
  if(status === "success") {
    page.render('example.png');
  }
  phantom.exit();
});
