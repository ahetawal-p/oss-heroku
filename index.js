var express = require('express');
var app = express();
var fs = require('fs');

app.set('port', (process.env.PORT || 5000));

//app.use(express.static(__dirname + '/html'));

// views is directory for all template files
app.set('views', __dirname + '/views');
app.set('view engine', 'ejs');

app.get('/', function(request, response) {
	var html = fs.readFileSync(__dirname+'/html/ahetawal-p.html', 'utf8')
  	response.send(html);
});

app.listen(app.get('port'), function() {
  console.log('Node app is running on port', app.get('port'));
});


