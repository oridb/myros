# Copyright 2015 Philipp Oppermann
#
# Licensed under the Apache License, Version 2.0 (the "License")#
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.section .multiboot_header
header_start:
    .long 0xe85250d6                # magic number (multiboot 2)
    .long 0                         # architecture 0 (protected mode i386)
    .long header_end - header_start # header length
    # checksum
    .long -(header_end - header_start + 0xe85250d6)

    # insert optional multiboot tags here

    # required end tag
    .short 0    # type
    .short 0    # flags
    .long 8    # size
header_end:
