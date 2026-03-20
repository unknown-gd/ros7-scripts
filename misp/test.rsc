:local filterName "MISP";

/ip/firewall/filter/

:foreach rule in=[find where comment=$filterName] do={
    :if ([get $rule disabled]) do={
        /log info "'$filterName' was enabled by \"MISP-Toggle\"";
        enable $rule;
    } else={
        /log info "'$filterName' was disabled by \"MISP-Toggle\"";
        disable $rule;
    }
}

chain=output action=drop protocol=icmp dst-address-list=misp out-interface-list=WAN1 log=no log-prefix="
