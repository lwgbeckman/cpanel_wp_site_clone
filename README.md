# Site clone script for a website using WordPress on a server with cPanel/WHM

### Download and make executable
```
wget https://raw.githubusercontent.com/lwgbeckman/cpanel_wp_site_clone/main/site_clone.sh
```
```
chmod +x site_clone.sh
```

### Usage
sh site_clone.sh [-d|f|h|v|V] [source_domain.tld] [destination_domain.tld]

### Help
```
sh site_clone.sh -h
```
```
Syntax: sh site_clone.sh [-d|f|h|v|V] [source_domain.tld] [destination_domain.tld]
options:
d       Dry run. Doesn't make any changes.
f       Force. Ignores all errors unless it reaches a critical error.
h       Print this Help.
v       Verbose mode. Prints out aditional information during certain operations.
V       Print software version.
```
