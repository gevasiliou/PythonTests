////////////////////////////////////////////////////////// 
/////  PhantomJS URL Scraper v.1.3 ///// 
// 
// Copyrighted by +A.M.Danischewski  2016+ (c)
// This program may be reutilized without limits, provided this 
// notice remain intact. 
// 
// Usage: phantomjs phantom_urls.js <URL> [["class"|"id"] [<query id/class name>]]
//
//   Argument 1: URL -- "https://www.youtube.com/watch?v=8TniRMwL2Vg" 
//   Argument 2: "class" or "id" 
//   Argument 3: If Argument 2 was provided, "class name" or "id name" 
// 
// By default this program will display ALL urls from a user supplied URL.  
// If a class name or id name is provided then only URL's from the class 
// or id are displayed.  
//  
/////////////////////////////////// 

var page = require('webpage').create(), 
    system = require('system'),
    address;

if (system.args.length === 1) {
  console.log(' Usage: phantomjs phantom_urls.js <URL> [["class"|"id"] [<query id/class name>]]');
  phantom.exit();
}

address = system.args[1];
querytype= system.args[2];
queryclass = system.args[3];
page.open(address, function(status) {
  if (status !== 'success') {
    console.log('Error loading address: '+address);
  } else {
   //console.log('Success! In loading address: '+address);   
  }
});

page.onConsoleMessage = function(msg) {
  console.log(msg);
}

page.onLoadFinished = function(status) {
   var dynclass="function() { window.class_urls = new Array(); window.class_urls_next=0; var listings = document.getElementsByClassName('"+queryclass+"'); for (var i=0; i < listings.length; i++) { var el = listings[i]; var ellnks=[].map.call(el.querySelectorAll('a'),function(link) {return link.getAttribute('href');}); var elhtml=el.innerHTML; window.class_urls.push(ellnks.join('\\n')); }; return window.class_urls;}"; 
   var    dynid="function() { window.id_urls = new Array(); window.id_urls_next=0; var listings = document.getElementById('"+queryclass+"'); var ellnks=[].map.call(listings.querySelectorAll('a'),function(link) {return link.getAttribute('href');}); var elhtml=listings.innerHTML; window.id_urls.push(ellnks.join('\\n'));  return window.id_urls;}";  
   var  allurls="function() { var links = page.evaluate(function() { return [].map.call(document.querySelectorAll('a'), function(link) { return link.getAttribute('href'); };); };); console.log(links.join('\\n')); }"; 
   var page_eval_function="";  
   if (querytype === "class") {
   console.log(page.evaluate(dynclass).toString().replace(/,/g, "\n")); 
   } else if (querytype === "id") {
   console.log(page.evaluate(dynid).toString().replace(/,/g, "\n")); 
   } else { 
   var links = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('a'), function(link) {
            return link.getAttribute('href');
        });
    });    
       console.log(links.join('\n'));
   }             
   phantom.exit();
};
