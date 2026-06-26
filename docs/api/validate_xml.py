#!/usr/bin/python3
#
# Copyright (c) 2010, Sascha Peilicke <saschpe@suse.de>, Novell Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA

import os, sys
from subprocess import call


def validate_schema(arg, dirname, filenames):
    """Validates XML files in a directory against their provided schema definition.

    Calls 'xmllint' to do the validation when a supported schema definition file is
    found. The supported schema definitions are RelaxNG, Schematron and XML Schema.
    """
    for filename in filenames:
        if filename.endswith('.xml'):                   # check for XML files
            relname = os.path.join(dirname, filename)   # relative filename from working directory
            basename = relname.rsplit('.', 1)[0]        # split of the file ending (aka '.xml')
            if os.path.exists(basename + '.xsd'):       # has a XML Schema file?
                call("xmllint --noout --schema {0} {1}".format(basename + '.xsd', relname).split(' '))
            elif os.path.exists(basename + '.rng'):     # has a RelaxNG schema file?
                call("xmllint --noout --relaxng {0} {1}".format(basename + '.rng', relname).split(' '))
            elif os.path.exists(basename + '.sch'):     # has a Schematron schema file? 
                call("xmllint --noout --schematron {0} {1}".format(basename + '.sch', relname).split(' '))
            else:                                       # has none unfortunately
                print("no schema to validate {0}".format(relname))


if __name__ == "__main__":                              # we're called directly
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        print("please provide a directory with XML files to validate!")
        sys.exit(1)

    os.path.walk(sys.argv[1], validate_schema, None)    # walk all files in the provided directory recursively
