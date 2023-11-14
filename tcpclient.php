<?php

//Creating a Socket
if(!($sock = socket_create(AF_INET, SOCK_STREAM, 0)))
{
    $errorcode = socket_last_error();
    $errormsg = socket_strerror($errorcode);
    die("Couldn't create socket: [$errorcode] $errormsg \n");
}
echo "1:: ---- Socket Created </br><br>";


//Connecting to Server
if(!socket_connect($sock, "127.0.0.1", 9999)){
    $errorcode = socket_last_error();
    $errormsg = socket_strerror($errorcode);
    die("Couldn't connect socket: [$errorcode] $errormsg </br>");
}
echo "2:: ---- Connection Established </br></br>";

//Send message to Server
$message = "Message from Web\r\n";
if(!socket_send($sock, $message, strlen($message), 0 )){
    $errorcode = socket_last_error();
    $errormsg = socket_strerror($errorcode);
    die("Couldn't not send data: [$errorcode] $errormsg </br>");
}
echo "3:: ---- Message sent </br></br>";
?>
