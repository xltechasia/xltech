# xltech
XLTech system scripts and utils for maintenance and builds

To be installed at /opt/xltech, with the xlt command used to access the scripts in ./bin (via link in /usr/bin or relevant path)

Basic command structure is;
  - xlt --help|-h
  - xlt \<command\> \<options\>|--help|-h

xlt exists to;
  - avoid polluting the system with commands on the path (one command to rule them all)
  - support any common pre-processing (i.e. what distro/package manager am I on, etc)
  
