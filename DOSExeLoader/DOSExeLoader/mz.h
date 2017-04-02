//
//  mz.h
//  DOSExeLoader
//
//  Created by john on 02.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#ifndef mz_h
#define mz_h

#define MZ_MAGIC    0x5A4D
#define MZ_BLOCK    0x200
#define MZ_PARA     0x10

struct MZHeader{
    unsigned short signature;
    unsigned short bytes_in_last_block;
    unsigned short blocks_in_file;
    unsigned short num_relocs;
    unsigned short header_paragraphs;
    unsigned short min_extra_paragraphs;
    unsigned short max_extra_paragraphs;
    unsigned short ss;
    unsigned short sp;
    unsigned short checksum;
    unsigned short ip;
    unsigned short cs;
    unsigned short reloc_table_offset;
    unsigned short overlay_number;
};

struct MZReloc{
    unsigned short offset;
    unsigned short segment;
};

#endif /* mz_h */
