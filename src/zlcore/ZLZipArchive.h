// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef ZLZIPARCHIVE_H
#define ZLZIPARCHIVE_H

#include <stdint.h>

//================================================================//
// ZLZipArchiveHeader
//================================================================//
class ZLZipArchiveHeader {
public:

	uint32_t	mSignature;			// 4 End of central directory signature = 0x06054b50
	uint16_t	mDiskNumber;		// 2 Number of this disk
	uint16_t	mStartDisk;			// 2 Disk where central directory starts
	uint16_t	mTotalDiskEntries;	// 2 Total number of entries on disk
	uint16_t	mTotalEntries;		// 2 Total number of central in archive
	uint32_t	mCDSize;			// 4 Size of central directory in bytes
	uint32_t	mCDAddr;			// 4 Offset of start of central directory, relative to start of archive
	uint16_t	mCommentLength;		// 2 ZIP file comment length
	
	//----------------------------------------------------------------//
	int		FindAndRead		( FILE* file );
};

//================================================================//
// ZLZipEntryHeader
//================================================================//
class ZLZipEntryHeader {
public:

	uint32_t	mSignature;				// 4 Central directory file header signature = 0x02014b50
	uint16_t	mByVersion;				// 2 Version made by
	uint16_t	mVersionNeeded;			// 2 Version needed to extract (minimum)
	uint16_t	mFlag;					// 2 General purpose bit flag
	uint16_t	mCompression;			// 2 Compression method
	uint16_t	mLastModTime;			// 2 File last modification time
	uint16_t	mLastModDate;			// 2 File last modification date
	uint32_t	mCrc32;					// 4 CRC-32
	uint32_t	mCompressedSize;		// 4 Compressed size
	uint32_t	mUncompressedSize;		// 4 Uncompressed size
	uint16_t	mNameLength;			// 2 File name length (n)
	uint16_t	mExtraFieldLength;		// 2 Extra field length (m)
	uint16_t	mCommentLength;			// 2 File comment length (k)
	uint16_t	mDiskNumber;			// 2 Disk number where file starts
	uint16_t	mInternalAttributes;	// 2 Internal file attributes
	uint32_t	mExternalAttributes;	// 4 External file attributes
	uint32_t	mFileHeaderAddr;		// 4 Relative offset of file header
	
	//----------------------------------------------------------------//
	int		Read	( FILE* file );
};

//================================================================//
// ZLZipFileHeader
//================================================================//
class ZLZipFileHeader {
public:

	uint32_t	mSignature;				// 4	Local file header signature = 0x04034b50 (read as a little-endian number)
	uint16_t	mVersionNeeded;			// 2	Version needed to extract (minimum)
	uint16_t	mFlag;					// 2	General purpose bit flag
	uint16_t	mCompression;			// 2	Compression method
	uint16_t	mLastModTime;			// 2	File last modification time
	uint16_t	mLastModDate;			// 2	File last modification date
	uint32_t	mCrc32;					// 4	CRC-32 (*not* to be trusted - Android)
	uint32_t	mCompressedSize;		// 4	Compressed size (*not* to be trusted - Android)
	uint32_t	mUncompressedSize;		// 4	Uncompressed size (*not* to be trusted - Android)
	uint16_t	mNameLength;			// 2	File name length
	uint16_t	mExtraFieldLength;		// 2	Extra field length

	//----------------------------------------------------------------//
	int		Read	( FILE* file );
};

//================================================================//
// ZLZipFileEntry
//================================================================//
class ZLZipFileEntry {
public:

	std::string		mName;
	uint32_t	mFileHeaderAddr;
	uint32_t	mCrc32;
	uint16_t	mCompression;
	uint32_t	mCompressedSize;
	uint32_t	mUncompressedSize;
	
	ZLZipFileEntry*	mNext;
};

//================================================================//
// ZLZipFileDir
//================================================================//
class ZLZipFileDir {
public:

	friend class ZLZipArchive;

	std::string		mName;
	
	ZLZipFileDir*	mNext;
	ZLZipFileDir*	mChildDirs;
	ZLZipFileEntry*	mChildFiles;

	//----------------------------------------------------------------//
	ZLZipFileDir*	AffirmSubDir		( const char* name, size_t len );

public:

	//----------------------------------------------------------------//
					ZLZipFileDir		();
					~ZLZipFileDir		();
};

//================================================================//
// ZLZipArchive
//================================================================//
class ZLZipArchive {
public:

	friend class ZLZipStream;

	std::string			mFilename;
    ZLZipFileDir*		mRoot;

	//----------------------------------------------------------------//
	void				AddEntry		( ZLZipEntryHeader* header, const char* name );

public:

	//----------------------------------------------------------------//
	void				Delete				();
	ZLZipFileDir*		FindDir				( char const* path );
	ZLZipFileEntry*		FindEntry			( char const* filename );
	int					Open				( const char* filename );
						ZLZipArchive		();
						~ZLZipArchive	();
};

#endif