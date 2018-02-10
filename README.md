# Automated Kali Hashcorp Box

## Overview
### what this repo will be for
So you can vagrant box update to get the new box that is created from this each month by a cron job on my server. This will allow for a fresh new image of Kali with the most up to date tools through the ease of vagrant and however you want to provision my kali box.

Based on vagrants help command (displayed below), this should destroy/delete anything from before the box was upgraded. 

```
$ vagrant box update --help
Usage: vagrant box update [options]

Updates the box that is in use in the current Vagrant environment,
if there any updates available. This does not destroy/recreate the
machine, so you'll have to do that to see changes.

To update a specific box (not tied to a Vagrant environment), use the
--box flag.
```

### grand scheme
So to get the new up to date kali box you would have to `vagrant destroy` and `vagrant up` it again. Then everything would be based on your Vagrantfile for provisioning.

### things to consider before `vagrant destroy`
- did you backup all your metasploit data? - `msfconsole -q -x "db_export -f xml /root/pentesting/metasploit-backups/general/metasploit-backup-main.xml; exit"`
- did you backup all your metasploit creds (doesn't get exported by metasploit by default...)? - `msfconsole -q -x "creds -o /root/pentesting/metasploit-backups/creds/metasploit-backup-creds.csv; exit"`
- do you have any customizations that could be automated in your Vagrantfile?
- linking your `/vagrant` folder to your home (in your Vagrantfile) to keep everything shared and doesn't get lost when destroying boxes (because it is on your local machine as a shared folder)

## Dependencies
- vagrant
- packer
- internet connection

### Future plans
- [ ] Create different kali box automations (i.e. with empire and other frameworks)
- [ ] docs...eventually :D
- [ ] different virtualization platforms
