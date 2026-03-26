### URL Updater Utility Script

Provides a set of remote tools to add URLs, delete URLs, and list the URLs in custom URL categories on an F5 BIG-IP.

----

##### How to use
1. Copy the Bash utility script to a Linux-based system
2. Enable script executation
   ```bash
   chmod +x urlupdater.sh
   ```
3. Execute by minimally providing the BIG-IP IP/hostname, the user name (prompts for password), a category name, and then a command (--list, --add, --del, --repl. --dump) and any corresponding additional options (--url, --file, --dryrun). See the *Examples* section below for additional usage hints.

   ```bash
   ./urlupdater.sh --bigip 172.16.1.84 --user admin --cat test-category --add --url https://www.mydomain.com/
   ```

----

##### URL format

URL category format requires a scheme (http://, https://), a domain name, and trailing forward slash, and may contain globbing patterns. Examples:

```bash
http://www.sitequest.com/
https://www.siterequest.com/
http://www.siterequest.com:8080/
http://*.sitequest.com/
https://www[0-9].siterequest.com/
```

----

##### Syntax
```bash
--help | -h     = show this help
--list | -l     = list entries in the specified URL category
--dump | -x     = dump the specified category to a file --> used with --file [file]
--add  | -a     = add an entry to the specified URL category. Used with --url (single url) or --file (url file)
--del  | -d     = delete an entry from the specified URL category. Used with --url (single url) or --file (url file)
--repl | -r     = replace the contents of the specified URL category. Used with --file (url file)
--cat  | -c     = a category name
--file | -f     = a url file used with --add, --del, and --repl
--url  | -u     = a single url used with --add and --del (ex. https://www.foo.com/)
--bigip| -b     = the IP address or hostname of the BIG-IP
--user | -i     = username for the BIG-IP (will prompt for password)
--dryrun        = echoes the resulting iControl REST call text to standard out instead of executing. Used with --add, --del, and --repl
```

##### Examples
```bash
Show help:            ./urlupdater.sh --help
List URLs:            ./urlupdater.sh --bigip 172.16.1.84 --user admin --cat test-category --list
Add single entry:     ./urlupdater.sh --bigip 172.16.1.84 --user admin --cat test-category --add --url https://www.foo.com/
Add file entries:     ./urlupdater.sh --bigip 172.16.1.84 --user admin --cat test-category --add --file testfile.txt
Delete single entry:  ./urlupdater.sh --bigip 172.16.1.84 --user admin --cat test-category --del --url https://www.foo.com/
Delete file entries:  ./urlupdater.sh --bigip 172.16.1.84 --user admin --cat test-category --del --file testfile.txt
Replace all entries:  ./urlupdater.sh --bigip 172.16.1.84 --user admin --cat test-category --repl --file testfile.txt
```
