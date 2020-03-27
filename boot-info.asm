.comment

**  These are not currently used, but keep for reference

.endc

partentryrec    .struct
    status      .fill 1 ; 80 represents bootable - 00 is inactive
    first_chs   .fill 3
    ptype       .fill 1
    lst_chs     .fill 3
    lba         .fill 4
    sectors     .fill 4
                .ends

bootrec         .struct
    void        .fill 446 ; 16 lines
    partition1  .dstruct partentryrec
    partition2  .dstruct partentryrec
    partition3  .dstruct partentryrec
    partition4  .dstruct partentryrec
    sig         .fill 2
                .ends
                
bootsector      .struct
                .fill 3 ; EB 3C 90
                .fill 8 ; MSDOS5.0
                .dstruct biosparamblock ; 25 bytes - BIOS Parameter Block
                .dstruct extendedbiosprm ; 26 bytes - Extended BIOS Param Block
                .fill 448 ; bootstrap code
                .fill 2 ; 55 AA
                .ends
                
biosparamblock  .struct
                .fill 2 ; bytes per second - should be 512
                .fill 1 ; sectors per cluster
                .fill 2 ; reserved sectors
                .fill 1 ; Number of FATs - should be 2
                .fill 2 ; Root Entries
                .fill 2 ; small sectors - 0 with large sectors set.
                .fill 1 ; media type - $F8 hard disk
                .fill 2 ; sectors per FAT
                .fill 2 ; sectors per track
                .fill 2 ; number of heades
                .fill 4 ; hidden sectors
                .fill 4 ; large sectors
                
                .ends
                
extendedbiosprm .struct
                .fill 1 ; physical disk number - floppies start at $0, hard disks at $80
                .fill 1 ; current heades
                .fill 1 ; signature $28 or $29
                .fill 4 ; volume serial number
                .fill 11 ; volume label
                .fill 8 ; system id - FAT12 or FAT16 depending on format

                .ends