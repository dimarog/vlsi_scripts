#!/pkg/qct/software/python/2.7.9/bin/python
# ===============================================================================

# ===============================================================================

import sys
import argparse
import getpass
import requests


#===============================================================================
# Function definition and usage
# ===============================================================================

INVALID_USAGE = 2
INVALID_FILE = 3
INTERNAL_ERROR = 4

DEBUG_URL = "http://127.0.0.1:8000"
#DEFAULT_URL = "https://ipcatalog-api.somewhere.com"
DEFAULT_URL = "https://ipcatalog.somewhere.com/ipcat/chip/"
TEST_URL = "https://ipcatalog-api-tst.somewhere.com"
ERROR_LOG = "ipcat_response.html"

"""
------------------------------------------------------------------------------
IP Catalog qctmakerelease script.
------------------------------------------------------------------------------

Usage: ipcat_makerelease.py --chip=<chip>
                            --version=<version>
                            --chipio-file=<file>
                            --de-file=<file>
                            --flat-file=<file>
                            --generics-file=<file>
                            --xpu-file=<file>
                            --swi-url=<file>
                            [ --json-file=<file> ]
                            [ --chipio-group=<gpiomap_group> ]
                            [ --url=<url> ]
Example:
  ipcat_makerelease.py --chip=aragorn --version=v1.0_p2q1r19.3
        --chipio-file=aragorn_io.xlsm
        --flat-file=ARM_ADDRESS_FILE.FLAT
        --json-file=ARM_ADDRESS_FILE.JSON
        --de-file=top.ipcat.csv
        --generics-file=top.ipcat_para.csv
        --xpu-file=top.ipcat_xpu.csv
        --swi-url=http://hwecgi.somewhere.com/prj/qct/chips/istari/sandiego/docs/SWI/HTML/latest_1.0/istari.index.html

Return value will be 0 on success, otherwise non-zero.
"""

#===============================================================================

def save_error_log(error_content):
    """
    Saves the error log in a html file
    """
    handle = open(ERROR_LOG, 'w')
    handle.write(error_content)
    handle.close()


#===============================================================================

def get_authentication_token (url, app_name):

    # Token based authentication
    print "[IPCat] Getting authentication token for release..."

    # Get the token for design elements and address file upload
    # print "[IPCat] Getting the token for design elements and address file upload..."
    resp = requests.post(url + '/api/account-token/',
                         data={'app_name': app_name}, verify=False)

    if resp.status_code != requests.codes.ok:
        if resp.status_code == 403 or resp.status_code == 401:
            print '[IPCat] Permission problem. Make sure you have valid credentials'
        else:
            print '[IPCat] Unexpected response from server (%d), see "%s" for details.' % (resp.status_code, ERROR_LOG)
            print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
            save_error_log(resp.text)
        sys.exit(resp.status_code)

    # Get the token from response
    try:
        token = resp.json()['token']
    except:
        print '[IPCat] Invalid response from server, see "%s" for details.' % (ERROR_LOG)
        print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
        save_error_log(resp.text)
        sys.exit(1)

    # Obtain the macaroon using the token
    # print "[IPCat] Getting the the macaroon using the token..."
    resp = requests.post(url + '/api/token-auth/',
                         headers={'Authorization': 'Token {0}'.format(token)}, verify=False)

    if resp.status_code != requests.codes.ok:
        if resp.status_code == 403 or resp.status_code == 401:
            print '[IPCat] Permission problem. Make sure you have valid token header'
            resp.raise_for_status()  # Raises "requests.exceptions.HTTPError"
        else:
            print '[IPCat] Invalid response from server, see "%s" for details.' % (ERROR_LOG)
            print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
            save_error_log(resp.text)
        sys.exit(resp.status_code)

    resp_data = resp.json()

    # Pass the serialized macaroon in the "Authorization" HTTP header
    headers = {
        'Authorization': 'Macaroon {0}'.format(resp_data['token']),
        'USERNAME': getpass.getuser()
    }

    return headers


# ===============================================================================

def main(argv):
    '''
    Main routine executed when run from the command line.
    '''

    # set up the params for the script
    parser = argparse.ArgumentParser(prog=argv)
    parser.add_argument('-c', '--chip')
    parser.add_argument('-v', '--version')
    parser.add_argument('-g', '--chipio-group')
    parser.add_argument('--chipio-file', nargs='?', type=argparse.FileType('rb'))
    parser.add_argument('--flat-file', nargs='?', type=argparse.FileType('rb'))
    parser.add_argument('--json-file', nargs='?', type=argparse.FileType('rb'))
    parser.add_argument('--generics-file', nargs='?', type=argparse.FileType('rb'))
    parser.add_argument('--swi-url')
    parser.add_argument('--de-file', nargs='?', type=argparse.FileType('rb'))
    parser.add_argument('--xpu-file', nargs='?', type=argparse.FileType('rb'))
    parser.add_argument('-u', '--url', nargs='?', default=DEFAULT_URL)
    parser.add_argument('-t', '--test', action="store_true")

    # convert the args to dictionary
    args = vars(parser.parse_args())
    chipio_group = args['chipio_group']
    chipio_file = args['chipio_file']
    flatfile = args['flat_file']
    jsonfile = args['json_file']
    defile = args['de_file']
    genericsfile = args['generics_file']
    xpufile = args['xpu_file']
    chip_version = args['version']
    chipname = args['chip']
    testurl = args['test']

    # verify chip , version , flat-file and de-file params
    if chipname is None:
        print "\n*** Must specify the chip name --chip=<chip>"
        sys.exit(INVALID_USAGE)

    if chip_version is None:
        print "\n*** Must specify the version number using --version=<version>"
        sys.exit(INVALID_USAGE)

    if flatfile is None and defile is None and genericsfile is None and \
                    xpufile is None and chipio_file is None and jsonfile is None:
        print "\n*** Warning: No files specified, database will not be modified."

    if flatfile is None:
        print "\n*** Must provide flatfile to upload --flat-file=<flat_file>"
        sys.exit(INVALID_USAGE)

    # Set the url to test url if test param is passed
    if testurl is True:
        args['url'] = TEST_URL

    # Disable warnings related to unverified HTTPS requests.
    try:
        import requests.packages.urllib3
        requests.packages.urllib3.disable_warnings()
    except:
        pass

    # Get the authentication token
    headers = get_authentication_token(args['url'], 'hwmakerelease')
    print ("DEBUG DIMA: ")
    print (headers)

    # Get the chip_id from server
    print "[IPCat] Getting chip id for %s..." % args['chip']
    resp = requests.get(args['url'] + '/api/1/hwtags/designelementfile',
                        params={'alias': chipname.lower()}, headers=headers, verify=False)
    print ("DEBUG DIMA: ")
    print (resp)

    if resp.status_code != requests.codes.ok:
        if resp.status_code == 403 or resp.status_code == 401:
            print '[IPCat] Permission problem. Make sure that your token is valid and authorized'
            resp.raise_for_status()
        else:
            print '[IPCat] Error retrieving Chip id: %s (%d).  See "%s" for details.' % (resp.reason, resp.status_code, ERROR_LOG)
            print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
            save_error_log(resp.text)
        return resp.status_code

    # verify response returned
    try:
        json_data = resp.json()
    except ValueError:
        print '[IPCat] Invalid response from server, see "%s" for details.' % (ERROR_LOG)
        print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
        save_error_log(resp.text)
        return 1

    print ("DEBUG DIMA: ")
    print json_data
    if len(json_data) == 0 or 'id' not in json_data[0]:
        print '[IPCat] Unable to find Chip %s in IP Catalog.' % args['chip']
        save_error_log(resp.text)
        return 1

    chip_id = json_data[0]['id']

    # validate chip_id is a valid integer.
    try:
        int(chip_id)
    except:
        print '[IPCat] Invalid chip id from server, see "%s" for details.' % ERROR_LOG
        print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
        save_error_log(resp.text)
        return 1


    print("DEBUG DIMA: stopping")
    exit()
    # Upload the address file.
    if flatfile:
        params = {}
        params['chip'] = chip_id
        params['version_number'] = args['version']
        if 'swi_url' in args:
            params['swi_url'] = args['swi_url']

        files = {'flat_file': args['flat_file']}
        if jsonfile:
            files.update({'json_file': jsonfile})

        # Populate the DB with the SWI file
        print "[IPCat] Uploading address file..."
        resp = requests.post(args['url'] + '/api/1/chipwizard/%d/address_flat_file/' % chip_id,
                             data=params, files=files, headers=headers, verify=False)

        if resp.status_code != requests.codes.ok:
            if resp.status_code == 403 or resp.status_code == 401:
                print '[IPCat] Permission problem. Make sure that your token is valid and authorized'
            else:
                print '[IPCat] Error uploading address file: %s, status=%d (see "%s" for details)' % (resp.reason, resp.status_code, ERROR_LOG)
                print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
                save_error_log(resp.text)
            return resp.status_code
        else:
            print "[IPCat] Upload of address file complete."

    # Upload the design elements .csv file.
    if defile:
        params = {}
        params['chip'] = chip_id
        params['chip_version']  = '0'
        params['revision_number'] = args['version']

        files = {'file': args['de_file']}

        # Populate the DB with the design elements file
        print "[IPCat] Uploading design elements file..."
        resp = requests.post(args['url'] + '/api/1/hwtags/designelementfile/%d/design_element_file/' % chip_id,
                             data=params, files=files, headers=headers, verify=False)

        if resp.status_code != requests.codes.ok:
            if resp.status_code == 403 or resp.status_code == 401:
                print '[IPCat] Permission problem. Make sure that your token is valid and authorized'
            else:
                print '[IPCat] Error uploading design elements file: %s, status=%d (see "%s" for details)' % (resp.reason, resp.status_code, ERROR_LOG)
                print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
                save_error_log(resp.text)
            return resp.status_code
        else:
            print "[IPCat] Upload of design elements file complete."

    # Upload the generics file.
    if genericsfile:
        params = {}
        params['chip'] = chip_id
        params['chip_version']  = '0'
        params['revision_number'] = args['version']

        files = {'file': genericsfile}

        # Populate the DB with the design elements file
        print "[IPCat] Uploading generics file..."
        resp = requests.post(args['url'] + '/api/1/generics/0/upload/',
                             data=params, files=files, headers=headers, verify=False)

        if resp.status_code != requests.codes.ok:
            if resp.status_code == 403 or resp.status_code == 401:
                print '[IPCat] Permission problem. Make sure that your token is valid and authorized'
            else:
                print '[IPCat] Error uploading generics file: %s, status=%d (see "%s" for details)' % (resp.reason, resp.status_code, ERROR_LOG)
                print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
                save_error_log(resp.text)
            return resp.status_code
        else:
            print "[IPCat] Upload of generics file complete."

    # Upload the xPU file.
    if xpufile:
        params = {}
        params['chip'] = chip_id
        params['chip_version']  = '0'
        params['revision_number'] = args['version']

        files = {'file': xpufile}

        # Populate the DB with the design elements file
        print "[IPCat] Uploading xPU file..."
        resp = requests.post(args['url'] + '/api/1/xpu/0/upload/',
                             data=params, files=files, headers=headers, verify=False)

        if resp.status_code != requests.codes.ok:
            if resp.status_code == 403 or resp.status_code == 401:
                print '[IPCat] Permission problem. Make sure that your token is valid and authorized'
            else:
                print '[IPCat] Error uploading xPU file: %s, status=%d (see "%s" for details)' % (resp.reason, resp.status_code, ERROR_LOG)
                print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
                save_error_log(resp.text)
            return resp.status_code
        else:
            print "[IPCat] Upload of xPU file complete."

    # Upload the Chip IO Spreadsheet.
    if chipio_file:
        params = {}
        params['chip'] = chip_id
        params['version_number'] = chip_version
        params['chipio_group'] = chipio_group

        files = {'file': chipio_file}

        # Populate the DB with the SWI file
        print "[IPCat] Uploading ChipIO file..."
        resp = requests.post(args['url'] + '/api/1/chipio_file/',
                             data=params, files=files, headers=headers, verify=False)

        if resp.status_code != requests.codes.ok:
            if resp.status_code == 403 or resp.status_code == 401:
                print '[IPCat] Permission problem. Make sure that your token is valid and authorized'
            else:
                print '[IPCat] Error uploading ChipIO file: %s, status=%d (see "%s" for details)' % (resp.reason, resp.status_code, ERROR_LOG)
                print '[IPCat] Please contact ipcat.support@somewhere.com for assistance.'
                save_error_log(resp.text)
            return resp.status_code
        else:
            #print resp.text
            print "[IPCat] Upload of ChipIO spreadsheet completed."

    return 0


if __name__ == "__main__":
    main(sys.argv[1:])

