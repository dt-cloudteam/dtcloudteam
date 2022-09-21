FROM ubuntu:latest
RUN apt update -y && apt upgrade -y && apt install telnet curl iputils-ping dnsutils htop tcptrack postgresql-client net-tools traceroute vim nano wget -y --no-install-recommends
CMD ["sh", "-c", "tail -f /dev/null"]