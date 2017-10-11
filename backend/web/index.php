<?php

header('Content-Type: text/plain', true, 200);
echo "I am the backend server\n";

echo "The responding server is: " . $_ENV['HOSTNAME'] . "\n\n";

$redis = new Redis();
$redis->connect('redis');
$redis->auth(file_get_contents('/run/secrets/db_password'));
echo 'Number of visits: ' . $redis->incr('visitors') . "\n";
