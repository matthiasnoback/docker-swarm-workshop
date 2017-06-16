<?php

header('Content-Type: text/plain', true, 200);
echo "I am the backend server\n\n";
echo "The responding server is: " . $_ENV['HOSTNAME'];
