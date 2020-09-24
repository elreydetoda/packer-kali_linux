# Automated Kali Vagrant Box


[![Kali Vagrant img](https://www.kali.org/wp-content/uploads/2018/10/kali-on-vagrant-768x273.png)](https://github.com/elreydetoda/packer-kali_linux)

**NOTE:** not Officially OffSec implementation of Vagrant and Kali.

[![CircleCI](https://circleci.com/gh/elreydetoda/packer-kali_linux/tree/master.svg?style=svg)](https://circleci.com/gh/elreydetoda/packer-kali_linux/tree/master)
[![CodeFactor](https://www.codefactor.io/repository/github/elreydetoda/packer-kali_linux/badge)](https://www.codefactor.io/repository/github/elreydetoda/packer-kali_linux)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/17c18e4c56b4477d8a21d10abbd94837)](https://app.codacy.com/app/unc741/packer-kali_linux?utm_source=github.com&utm_medium=referral&utm_content=elreydetoda/packer-kali_linux&utm_campaign=Badge_Grade_Dashboard)
[![Gitter](https://img.shields.io/gitter/room/elreydetoda/packer-kali_linux.svg?color=red)](https://gitter.im/packer-kali_linux/community)
[![Release Version](https://img.shields.io/github/release/elreydetoda/packer-kali_linux.svg)](https://github.com/elreydetoda/packer-kali_linux/releases/latest)

<!-- If the build status if failing please checkout [pinned issues](https://github.com/elreydetoda/packer-kali_linux/issues), and if there are no pinned issues then please file a detailed bug issue (template comming soon). -->

## Presentation

* Slideshow - [https://slides.com/elrey741/redops](https://slides.com/elrey741/redops)
* Video
  * (coming soon)[SELF (Southeast Linuxfest)](https://www.youtube.com/user/southeastlinuxfest/playlists)
  * [bsides chs](http://youtu.be/9EnDotVmcl8)
* Blog posts
  * Part 1: [https://blog.secureideas.com/2018/09/automating-red-team-homelabs-part-1-kali-automation.html](https://blog.secureideas.com/2018/09/automating-red-team-homelabs-part-1-kali-automation.html)
    * This blog post is a high level overview as to what I want to use this repo for
  * Part 2: [https://blog.secureideas.com/2019/05/automating-red-team-homelabs-part-2-build-pentest-destroy-and-repeat.html](https://blog.secureideas.com/2019/05/automating-red-team-homelabs-part-2-build-pentest-destroy-and-repeat.html)
    * This blog post is a deep dive into using packer and how I automated this github repo.

<!--
## Quick Start

### Use case #1

This will be if you just simply want to use this image and use my build of Kali Linux that gets built weekly on Saturdays. (For best user experience I will be using another repo of mine that has some additional provisioning (even if you don't want to use mine you can still look at what I am doing, in case you want to do something similar), which will be [here](https://github.com/elreydetoda/vagrant-files/tree/master/elrey741_kali-linux_amd64). Feel free to do your own thing if you know what you are doing: https://app.vagrantup.com/elrey741/boxes/kali-linux_amd64)

* make sure you have all the software installed that is needed.
  * [vagrant](https://www.vagrantup.com/downloads.html)
  * [virtualbox](https://www.virtualbox.org/wiki/Downloads) or vmware\*
    * \* - for vmware you need additional vagrant specific [plugins](https://www.vagrantup.com/docs/vmware/installation.html), also not providing a download link for vmware because if you know about it you most likely already have it installed.
  * git (optional) (if you want to clone the software instead of just download)
* Download necessary files- simply git or wget the files
  * wget https://github.com/elreydetoda/vagrant-files/archive/master.zip`
  * git clone https://github.com/elreydetoda/vagrant-files.git
* cd into the necessary directory
  * `cd vagrant-files/elrey741_kali-linux_amd64`
* start download
  * `vagrant up`
* start use
  * `vagrant ssh`

*NOTE*: for general use condsiderations, please checkout the [things to consider](#things_to_consider)

### Use case #2
-->

## Overview

### Vagrant Cloud Image

here is my account on vagrant cloud (which should list all the packer builds for this repo): [https://app.vagrantup.com/elrey741/](https://app.vagrantup.com/elrey741/)

and specifically here is the vagrant box for the master branch: [https://app.vagrantup.com/elrey741/boxes/kali-linux_amd64](https://app.vagrantup.com/elrey741/boxes/kali-linux_amd64)

### VM info

* user: vagrant
* pass: vagrant

#### Installed software

listed in the scripts directory: [here](https://github.com/elreydetoda/packer-kali_linux/tree/master/prov_packer)

### what this repo will be for

So you can vagrant box update to get the new box that is created from this each month by a cron job on my server. This will allow for a fresh new image of Kali with the most up to date tools through the ease of vagrant and however you want to provision my kali box.

Based on vagrants help command (displayed below), this should destroy/delete anything from before the box was upgraded.

```bash
$ vagrant box update --help
Usage: vagrant box update [options]

Updates the box that is in use in the current Vagrant environment,
if there any updates available. This does not destroy/recreate the
machine, so you'll have to do that to see changes.

To update a specific box (not tied to a Vagrant environment), use the
--box flag.
```

### grand scheme

![packer vagrant eco](https://blog.secureideas.com/wp-content/uploads/2018/09/packer_vagrant_eco.png)
So to get the new up to date kali box you would have to `vagrant destroy` and `vagrant up` it again. Then everything would be based on your Vagrantfile for provisioning.

### things to consider

before `vagrant destroy`

* did you backup all your metasploit data? - `msfconsole -q -x "db_export -f xml /root/pentesting/metasploit-backups/general/metasploit-backup-main.xml; exit"`
* did you backup all your metasploit creds (doesn't get exported by metasploit by default...)? - `msfconsole -q -x "creds -o /root/pentesting/metasploit-backups/creds/metasploit-backup-creds.csv; exit"`
* do you have any customizations that could be automated in your Vagrantfile?
* putting all your data in your `/vagrant` folder is ideal, to keep everything shared and making sure it doesn't get lost when destroying boxes (because it is on your local machine as a shared folder)

## Dependencies

* vagrant
* packer
* internet connection

### Future plans

* [ ] Create different kali box automations (i.e. with empire and other frameworks)
* [ ] docs...eventually :D
* [ ] different virtualization platforms (virtualbox)
