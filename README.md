# HTTPMailbox

Mailbox for HTTP Messages to enable Asynchronous RESTful communication and group communication over HTTP.

## Server Requirements

* Ruby
* Ruby Gems
 * sinatra
 * fluidinfo
 * rack-cors
 * thin (optional, can be used any web server)

## Configuration

Create an account on [fluidinfo](https://fluidinfo.com/accounts/new/) and add credentials in 'http_mailbox.rb' file. Also change the URL for your HTTP Mailbox instance including port number if not standard.

## Running Server

To run the server on default Sinatra port number 4567, issue the follwoing command:

    $ ruby http_mailbox.rb

To run it on a different port number (say 12345), the command will look like:

    $ ruby http_mailbox.rb -p 12345

If everything goes well, your HTTP Mailbox instance is up and running. Now it is ready to respond to following types of HTTP requests.

    POST /hm/http://example.com/ HTTP/1.1
    GET /hm/http://example.com/ HTTP/1.1

Note: Make sure the port number in use is open and accessible.

## TODO

* Detailed documentation and specifications of HTTP Mailbox
* Refactoring the code to allow various data storage options
* Light validation to restrict the system to only allow valid media types
* Extended support for additional HTTP Mailbox headers