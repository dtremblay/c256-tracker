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
    void        .fill 446 ; 16 lines  ; offset $1BE
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
                .fill 2 ; bytes per sector - should be 512 ; offset 0x0B
                .fill 1 ; sectors per cluster              ; offset 0x0D
                .fill 2 ; reserved sectors                 ; offset 0x0E
                .fill 1 ; Number of FATs - should be 2     ; offset 0x10
                .fill 2 ; Root Entries                     ; offset 0x11
                .fill 2 ; small sectors - 0 with large sectors set. ; offset 0x13
                .fill 1 ; media type - $F8 hard disk       ; offset 0x15
                .fill 2 ; sectors per FAT                  ; offset 0x16
                .fill 2 ; sectors per track                ; offset 0x18
                .fill 2 ; number of heads                  ; offset 0x1A
                .fill 4 ; hidden sectors                   ; offset 0x1C
                .fill 4 ; large sectors                    ; offset 0x20
                
                .ends
                
extendedbiosprm .struct
                .fill 4  ; logical sectors per FAT          ; offset 0x24
                .fill 2  ; drive description                ; offset 0x28
                .fill 2  ; version                          ; offset 0x2A
                .fill 4  ; cluster number of root directory start   ; offset 0x2C
                .fill 2  ; Logical sector number of FS Information Sector  ; offset 0x30
                .fill 2  ; first logical sector number of a copy of the three FAT32 boot sectors  ; offset 0x32

                .ends