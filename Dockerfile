FROM ubuntu:14.04

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    hostapd \
    dnsmasq

RUN echo "#!/bin/bash\nservice dnsmasq start > /dev/null 2>&1\nservice hostapd start > /dev/null 2>&1" > /usr/bin/start
RUN chmod u+x /usr/bin/start

CMD ["/bin/bash"]
