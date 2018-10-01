var page = require('webpage').create();
var url = 'http://www.etsy.com/search?q=hello%20kitty';

page.open(url, function(status) {
    // list all the a.href links in the hello kitty etsy page
    var links = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('a.listing-thumb'), function(link) {
            return link.getAttribute('href');
        });
    });
    console.log(links.join('\n'));
    phantom.exit();
});
