#!/usr/bin/env python3

import sys
from midas.node import BaseNode
from midas import utilities as mu


# ------------------------------------------------------------------------------
# Create a Node
# ------------------------------------------------------------------------------
class NodeExampleA(BaseNode):
    """ MIDAS example node A. """

    def __init__(self, *args):
        """ Initialize example node. """
        super().__init__(*args)

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
