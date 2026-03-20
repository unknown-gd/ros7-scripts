# DNS
:local dns ( [ip dns get servers ], [ip dns get dynamic-servers] );

/log info "DNS:";
foreach number, nameserver in=$dns do={
    /log info (($number + 1) . ". " . $nameserver);
}
