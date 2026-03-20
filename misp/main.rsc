# MISP - Multi-ISP
# Script name & prefix
:local scriptName "MISP";
:local scriptPrefix "[$scriptName]";

# Ping attempts count
:local attempts 4;

# Ping timeout ( time in ms, maximum ping response time for one ping )
:local timeout 1000;

# Expected percentage of provider stability ( 0 - 100 % )
:local minimalStability 100;

# Route comment prefix ( aka WAN1, WAN2 and etc. )
:local routePrefix "WAN";

# Interface comment prefix ( for example ISP1, ISP2, IS3 and etc. )
:local interfacePrefix "ISP";

# Temporary DNS route name ( Creates temporary routes for dns when a reachability check is performed, this name is required so that existing routes are not deleted )
:local dnsRoutingName "Temporary $scriptName DNS Route"

# Telegram bot token that will send messages (without bot prefix)
:local telegramBotToken "";

# Telegram chat ID to which the bot will send messages
:local telegramChatID "";

# Custom action after isp change
:local customAction do={
    # :local name ($interfaceData->"name");
    # :local comment ($interfaceData->"comment");
    # :local fullName ("$comment ($name)");

    # /log info "Wow new interface is $fullName";
}

# Below is code area, please do not modify it!

# Clamps a number between a minimum and maximum value
if ($minimalStability < 0) do={
    :set minimalStability 0;
} else {
    if ($minimalStability > 100) do={
        :set minimalStability 100;
    }
}

# Variable formatting
:set timeout ($timeout . "ms");
:set routePrefix ("$routePrefix\\d+");
:set interfacePrefix ("$interfacePrefix\\d+");

# DNS searching
:local dns ( [/ip dns get dynamic-servers], [/ip dns get servers ] );
/log info ("$scriptPrefix Detected $[:len $dns] DNS IPs.");

# Superior interface searching
/log info "$scriptPrefix Superior interface searching...";
:local interfaceData false;
:local maxPercentage 0;

# Interface performing
:foreach interface in=[/interface print as-value where comment~$interfacePrefix] do={
    if ($maxPercentage < $minimalStability) do={
        :local name ($interface->"name");
        :local successful 0;
        :local total 0;

        :foreach iRoute in=[/ip route print as-value where dst-address=0.0.0.0/0 comment~$routePrefix immediate-gw~$name] do={
            :local gateway ($iRoute->"gateway");
            /log info "$scriptPrefix Gateway '$gateway' for interface '$name' has been found, testing is running...";

            :foreach address in=$dns do={
                :local ipv4 [:toip $address];

                # Only IPv4 is supported now.
                :if ([:typeof $ipv4] = "ip") do={
                    # DNS Route Create
                    /ip route add distance=1 dst-address=($address . "/32") gateway=$gateway scope=10 target-scope=11 comment=$dnsRoutingName;
                    :delay "25ms";

                    # DNS Ping
                    :local isSuccessful false;
                    :set total ($total + 1);

                    :for i from=1 to=$attempts do={
                        if ($isSuccessful = false and [/tool ping address=$ipv4 interface=$name interval=$timeout count=1] > 0) do={
                            :set successful ($successful + 1);
                            :set isSuccessful true;
                        }
                    }

                    # DNS Route Remove
                    /ip route remove [find where distance=1 dst-address=($address . "/32") gateway=$gateway scope=10 target-scope=11 comment=$dnsRoutingName];
                }
            }

            # Percentage calculation
            :local percentage (($successful * 100) / $total);
            :if ($percentage > $maxPercentage) do={
                :set maxPercentage $percentage;
                :set interfaceData $interface;
            }

            /log info ("$scriptPrefix Interface '" . $name . "' was up " . $percentage . "% of IPv4 DNS.");
        }
    }
}

# Actions
:if (($interfaceData = false) or ($maxPercentage = 0)) do={
    /log warning "$scriptPrefix Superior interface was not found, failure.";
} else {
    :local name ($interfaceData->"name");
    :local fullName ($interfaceData->"comment" . " ($name)");

    /log info ("$scriptPrefix Selected new superior interface '$fullName' with " . $maxPercentage . "% of successful pings to the router's IPv4 DNS.");

    # Route searching
    :local masterRoutes [/ip route print as-value where dst-address=0.0.0.0/0 comment~$routePrefix immediate-gw~$name];
    :local routes [/ip route print as-value where dst-address=0.0.0.0/0 comment~$routePrefix];
    /log info ("$scriptPrefix Detected " . ([:len $routes]) . " valid IPv4 and " . ([:len $masterRoutes]) . " master routes, processing...");

    # IPv4 Routing
    :local changes 0;
    :local sendNotification false;

    :local nextDistance 1;
    :foreach iRoute in=$routes do={
        :local id ($iRoute->".id");
        :local name ($iRoute->"comment");

        :local newDistance 1;
        :foreach iMasterRoute in=$masterRoutes do={
            :if (($iMasterRoute->".id") != $id) do={
                :set nextDistance ($nextDistance + 1);
                :set newDistance $nextDistance;
            }
        }

        :local oldDistance ($iRoute->"distance");
        if ($oldDistance != $newDistance) do={
            /log warning ("$scriptPrefix IPv4 routing '$name' distance changed '$oldDistance' -> '$newDistance'");
            /ip route set $id distance=$newDistance;
            :set changes ($changes + 1);

            if (($newDistance = 1) and ($sendNotification = false)) do={
                :set sendNotification true;
            }
        }
    }

    if ($changes > 0) do={
        # Telegram Bot Messages
        if (($sendNotification = true) and ([:len $telegramBotToken] >= 32) and ([:len $telegramChatID] >= 8)) do={
            :local telegramMessage "$[/system clock get time]/$scriptName - Selected new superior interface '$fullName' on '$[/system identity get name]'.";
            /tool fetch ("https://api.telegram.org/bot" . $telegramBotToken . "/sendMessage?chat_id=" . $telegramChatID . "&parse_mode=Markdown&text=" . $telegramMessage ) keep-result=no;
            /log info "$scriptPrefix A notification has been sent to Telegram chat.";
        }

        # Drop all connections
        :local connections [/ip firewall connection find];
        /ip firewall connection remove $connections;
        /log warning ("$scriptPrefix Cleared #" . ([:len $connections]) . " connections.");

        # DDNS Update
        /ip cloud force-update;
        /log warning "$scriptPrefix DDNS has been forced to update.";

        $customAction interfaceData=$interfaceData routes=$routes masterRoutes=$masterRoutes;
    } else {
        /log info "$scriptPrefix All required actions have already been accomplished, canceling...";
    }
}
