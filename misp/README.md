# MISP - Multi-ISP
A script that automatically switches ISP's in the event of unavailability or high latency, automatically selecting the best provider based on latency to the DNS servers.

**Attention**: To work properly, script must run automatically at least once an hour, you can use sheduler for this.

## Configuration - please note
The script searches for interfaces, assuming that you use a consistent naming convention for them.

The rest of the configuration is contained within the script itself and is described there.

### Interfaces
All provider interfaces must have a comment in the following format: `ISP{number} - {additional info}`

Examples:
- ISP1 - Vodafone (132.23.4.1)
- ISP2 - Orange, something...
- ISP2 - Vodafone
...

### Routes
For **each provider**, you must create separate `/ip/route` with a `distance` value higher than the default `1`; your current/main ISP **should always be 1**.

All provider routes must have a comment in the following format: `WAN{number} - {additional info}`

Examples:
- WAN1 - Vodafone
- WAN2 - Orange, something...
- WAN3 - Deutsche Telekom
...

### Additional Info
The term `number` refers to integers; floating-point numbers, hexadecimal numbers, and other types of numbers **ARE NOT ACCEPTABLE**.
