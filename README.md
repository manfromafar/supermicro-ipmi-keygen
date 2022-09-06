# supermicro-ipmi-keygen

https://peterkleissner.com/2018/05/27/reverse-engineering-supermicro-ipmi/

Reverse Engineering Supermicro IPMI
May 27, 2018 | by Kleissner

Supermicro enforces a vendor-lock in on BIOS updates via IPMI, even though they publish the update files for free here. The only free alternative is to time-travel to 1995 and boot from a DOS disk to supply the update. All other options (including the Supermicro Server Manager) require a license.



They published BIOS updates to address Spectre and Meltdown vulnerabilities, yet make it almost impossible to actually perform the update. Even if you go their suggested way, buying a key from an authorized Supermicro reseller people on the internet report it’s difficult and time consuming getting them. I was quoted 25 EUR and an estimated 2 weeks delivery time.

You buy a brand new product, it has a known vulnerability and you should pay for the update?! This is simply NOT acceptable. As the owner of my device I shall be free to update it. Therefore, I spent exactly 1 night reverse engineering this thing to figure out the license key algorithm. tl;dr here is the algorithm to generate those license keys:

MAC-SHA1-96(INPUT: MAC address of BMC, SECRET KEY: 85 44 E3 B4 7E CA 58 F9 58 30 43 F8)

Anybody can create the license key on https://cryptii.com/pipes/QiZmdA by typing on the left side (select Bytes) the MAC address of the IPMI (the BMC), select in the middle HMAC and SHA-1, enter the secret key and on the right side the License Key will appear!



This was successfully tested with Supermicro mainboards from 2013-2018. It appears they have not changed the algorithm and use the same “secret”. The first 6 groups go in here:



Update 1/14/2019: The Twitter user @astraleureka posted this code perl code which is generating the license key:
```
#!/usr/bin/perl
use strict;
use Digest::HMAC_SHA1 'hmac_sha1';
my $key  = "\x85\x44\xe3\xb4\x7e\xca\x58\xf9\x58\x30\x43\xf8";
my $mac  = shift || die 'args: mac-addr (i.e. 00:25:90:cd:26:da)';
my $data = join '', map { chr hex $_ } split ':', $mac;
my $raw  = hmac_sha1($data, $key);
printf "%02lX%02lX-%02lX%02lX-%02lX%02lX-%02lX%02lX-%02lX%02lX-%02lX%02lX\n", (map { ord $_ } split '', $raw);
```

Update 3/27/2019: There is also Linux shell version that uses openssl:
```
echo -n 'bmc-mac' | xxd -r -p | openssl dgst -sha1 -mac HMAC -macopt hexkey:8544E3B47ECA58F9583043F8 | awk '{print $2}' | cut -c 1-24
```
Update 9/15/2019: Twitter user @zanejchua provided the link https://cryptii.com/pipes/QiZmdA which makes it easier to generate the code.
Update 6/8/2021: Ben provided the following improved script:
```
#!/bin/bash
read -p "IPMI MAC: " macaddr
echo -n $macaddr | xxd -r -p | openssl dgst -sha1 -mac HMAC -macopt hexkey:8544E3B47ECA58F9583043F8 | awk '{print $2}' | cut -c 1-24 | sed 's/./&-/4;s/./&-/9;s/./&-/14;s/./&-/19;s/./&-/24;'
```

Information about IPMI (skip this if you’re an expert)
The IPMI is a remote management mechanism of servers, embedded in a chip that is separated from the typical resources accessible by the operating system. It allows remote management of servers even when it’s turned off. It’s really useful when your server is not responding and you don’t to want or can’t physically go there to troubleshoot. You can even install an OS via IPMI, start the server & even go into the BIOS. Thanks to HTML5 Supermicro switched away from those old Java applets (anyone developing anything in Java should be banned to a far, far remote island; Java should die in a fire, it’s slow and has 9999 vulnerabilities and on top of that Oracle will go after you for trademark and patent troll reasons even though it’s open source).

References that helped
I want to point out previous research work which helped me a lot.

Getting a root shell on the IPMI
binwalk Firmware Analysis Tool
Step 1: Download & Extract the Firmware
Supermicro offers the IPMI update files for free on their website. You need to select your mainboard and download the IPMI update file. Among other files it will contain 1 large firmware blob, in this case “REDFISH_X10_366.bin”.



The tool binwalk will scan the binary and look for signatures of known formats:

HEXADECIMAL DESCRIPTION
--------------------------------------------------------------------
0x19300 CRC32 polynomial table, little endian
0x400000 CramFS filesystem, little endian, size: 14254080, version 2, sorted_dirs, CRC 0xF105D0D5, edition 0, 8088 blocks, 1086 files
0x1400000 uImage header, header size: 64 bytes, header CRC: 0x8290B85A, created: 2017-06-09 12:33:02, image size: 1537474 bytes, Data Address: 0x40008000, Entry Point: 0x40008000, AA328F72, OS: Linux, CPU: ARM, image type: OS Kernel Image, compression type: gzip, image name: "21400000"
0x1400040 gzip compressed data, maximum compression, has original file name: "linux.bin", from Unix, last modified: 2017-06-09 12:01:11
0x1700000 CramFS filesystem, little endian, size: 7507968, version 2, sorted_dirs, CRC 0x19806BFF, edition 0, 2973 blocks, 407 files
Use a hex editor (such as HxD) to extract the CramFS binaries and store them to new files. It is an embedded compressed Linux file system that contains the files that we are interested in.



Next get a Linux system and mount both files each with this command and then dump all files into a tar file:

mount -o loop -t cramfs extracted.bin mnt1
tar -czf mnt1.tar.gz mnt1
Congrats! You now have the actual files of the IPMI system.



Step 2: Reverse engineer the interesting files on the IPMI file system
Finding the HTML/JS code that provides the user interface for activation was easy: Use the browser’s built-in developer tools (F12) to look at the code, then look for the same code on the extracted IPMI file system.

As you can see below, the IPMI website (that you visit as system administrator) calls “/cgi/ipmi.cgi” with certain parameters for checking if the key is valid.



Here are the breadcrumbs I followed from the website part:



The response is XML with check set to 0 if invalid and 1 if valid (it’s weird that they do not use JSON instead):



Next, we need to use IDA Pro and open the file “ipmi.cgi” that is stored on the IPMI file system and that we extracted in the previous step. Below you can see the code that handles the license check. By reading this code, you can see how the license is supposed to look like. The first loop is hex-decoding the input, i.e. The text key “1234-00FF-0000-0000-0000-0000” becomes binary (12 bytes) 12 34 00 FF 00 00 00 00 00 00 00 00.



The actual check of the license is done in another file “libipmi.so” which implements the referenced function oob_format_license_activate:



You can see here already the actual license key algorithm referenced – HMAC_SHA1. It is important to notice the 12 in the function call, which means 96 bits. The 96 bits is exactly the length of the key, represented in hex to the end-user.

Interestingly there is a function “oob_format_license_create” which creates the license and is even easier to read. You can see directly the reference to the private keys. “oob” means out-of-band, i.e. processing the update via IPMI.



The Supermicro keys are:

HSDC Private Key: 39 CB 2A 1A 3D 74 8F F1 DE E4 6B 87

OOB Private Key: 85 44 E3 B4 7E CA 58 F9 58 30 43 F8

At the beginning of this blog post it is explained how you can easily use this to create your own Supermicro License Key.
