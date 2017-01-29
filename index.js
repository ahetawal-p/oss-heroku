var express = require('express');
var app = express();
var fs = require('fs');
var pg = require('pg');
var Q = require('q');
var url = require('url');
var favicon = require('serve-favicon');
var path = require('path');

var databaseURL = process.env.DATABASE_URL || "postgres://localhost:5432/oss-dashboard";

app.set('port', (process.env.PORT || 5000));

//app.use(favicon(path.join(__dirname, 'html', 'favicon.ico')));
app.use('/html',express.static(path.join(__dirname, 'html')));

app.get('/', function(request, response) {
	var endpoint = 'AllAccounts';
	dbCalls("select count(*) FROM result_store WHERE endpoint=($1)", [endpoint], true)
	.then(function(result){
		if(result && result.count == 0) {
				console.log("Serving first record");
				serveFirstRecord(response);
			} else {
				serveValidEndpointRecord(response, endpoint);
			}
	});
});


app.get('/ossdash/:type', function(request, response) {
	var endpoint = request.params.type;
 	serveValidEndpointRecord(response, endpoint)
});



// production error handler
// no stacktraces leaked to user
app.use(function(err, req, res, next) {
  res.status(err.status || 500);
  console.log(err);
  res.send({
        message: err.message,
         error: {}
    });
});


serveFirstRecord = function(response) {
	dbCalls("select html FROM result_store limit 1", [], true, true)
	.done(function(result){
		if(result){
			var htmlResult = result['html'];
			if(htmlResult){
				response.send(htmlResult);
			}
		} else {
			response.send("No content found");
		}
	},
    function(error){
    	console.log(error);
    	next(error);
	});
}


serveValidEndpointRecord = function(response, endpoint) {
	dbCalls("select html FROM result_store WHERE endpoint=($1)", [endpoint], true, true)
	.done(function(result){
		if(result){
			var htmlResult = result['html'];
			if(htmlResult){
				response.send(htmlResult);
			}
		} else {
			response.send("No content found");
		}
	},
    function(error){
    	console.log(error);
    	next(error);
	});


}



dbCalls = function (sql, values, singleItem, dontLog) {
	if (!dontLog) {
        typeof values !== 'undefined' ? console.log(sql, values) : console.log(sql);
    }
    var deferred = Q.defer();
    pg.connect(databaseURL, function (err, conn, done) {
        if (err) return deferred.reject(err);
        try {
            conn.query(sql, values, function (err, result) {
                done();
                if (err) {
                    deferred.reject(err);
                } else {
                    if(result.command == 'UPDATE' || result.command == 'INSERT'){
                        deferred.resolve(result.rowCount);
                    } else {
                        deferred.resolve(singleItem ? result.rows[0] : result.rows);
                    }
                }
            });
        }
        catch (e) {
            done();
            deferred.reject(e);
        }
    });
    return deferred.promise;
};

app.listen(app.get('port'), function() {
  console.log('Node app is running on port', app.get('port'));
});


