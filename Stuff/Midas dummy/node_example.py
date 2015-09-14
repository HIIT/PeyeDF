#!/usr/bin/env python3

import sys
import time
import numpy as np
from midas.node import BaseNode, lsl
from midas import utilities as mu


# ------------------------------------------------------------------------------
# Create an Example Node A based on the Base Node
# ------------------------------------------------------------------------------
class NodeExampleA(BaseNode):
    """ MIDAS example node A. """

    def __init__(self, *args):
        """ Initialize example node. """
        super().__init__(*args)
        self.metric_functions.append(self.test)

    def test(self, x, p1=0, p2=0):
        """ Testing function that echoes inputs it gets"""
        print('>>>>>>>>>>>')
        print("\tNumber of channels=%d" % len(x['data']))
        for idx, ch in enumerate(x['data']):
            print("\t\tCh%d: %d samples" % (idx, len(ch)))
        print("\tArguments:")
        print("\t\targ1=%s" % p1)
        print("\t\targ2=%s" % p2)
        print("\tData:")
        for d in x['data']:
            print("\t\t" + str(d))
        print("\tTime:")
        for t in x['time']:
            print("\t\t" + str(t))
        return 1

# ------------------------------------------------------------------------------
# Run the node if started from the command line
# ------------------------------------------------------------------------------
if __name__ == '__main__':
    node = mu.midas_parse_config(NodeExampleA, sys.argv)
    if node is not None:
        node.start()
        node.show_ui()
# ------------------------------------------------------------------------------
# EOF
# ------------------------------------------------------------------------------
