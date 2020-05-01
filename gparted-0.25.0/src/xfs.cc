/* Copyright (C) 2004 Bart
 * Copyright (C) 2008, 2009, 2010 Curtis Gedak
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, see <http://www.gnu.org/licenses/>.
 */
 
 
#include "../include/xfs.h"

namespace GParted
{

FS xfs::get_filesystem_support()
{
	FS fs ;
	fs .filesystem = GParted::FS_XFS ;

	fs .busy = FS::GPARTED ;

	if ( ! Glib::find_program_in_path( "xfs_db" ) .empty() ) 	
	{
		fs .read = GParted::FS::EXTERNAL ;
		fs .read_label = FS::EXTERNAL ;
	}

	if ( ! Glib::find_program_in_path( "xfs_admin" ) .empty() ) 	
	{
		fs .write_label = FS::EXTERNAL ;
		fs .read_uuid = FS::EXTERNAL ;
		fs .write_uuid = FS::EXTERNAL ;
	}

	if ( ! Glib::find_program_in_path( "mkfs.xfs" ) .empty() )
	{
		fs .create = GParted::FS::EXTERNAL ;
		fs .create_with_label = GParted::FS::EXTERNAL ;
	}
	
	if ( ! Glib::find_program_in_path( "xfs_repair" ) .empty() ) 	
		fs .check = GParted::FS::EXTERNAL ;
	
	//Mounted operations require mount, umount and xfs support in the kernel
	if ( ! Glib::find_program_in_path( "mount" ) .empty()  &&
	     ! Glib::find_program_in_path( "umount" ) .empty() &&
	     fs .check                                         &&
	     Utils::kernel_supports_fs( "xfs" )                   )
	{
		//Grow
		if ( ! Glib::find_program_in_path( "xfs_growfs" ) .empty() )
			fs .grow = FS::EXTERNAL ;

		//Copy using xfsdump, xfsrestore
		if ( ! Glib::find_program_in_path( "xfsdump" ) .empty()    &&
		     ! Glib::find_program_in_path( "xfsrestore" ) .empty() &&
		     fs .create                                               )
			fs .copy = FS::EXTERNAL ;
	}

	if ( fs .check )
		fs .move = GParted::FS::GPARTED ;

	fs .online_read = FS::GPARTED ;
#ifdef ENABLE_ONLINE_RESIZE
	if ( Utils::kernel_version_at_least( 3, 6, 0 ) )
		fs .online_grow = fs .grow ;
#endif

	fs .MIN = 32 * MEBIBYTE ;//official minsize = 16MB, but the smallest xfs_repair can handle is 32MB...
	
	return fs ;
}

void xfs::set_used_sectors( Partition & partition ) 
{
	if ( ! Utils::execute_command( 
			"xfs_db -c 'sb 0' -c 'print blocksize' -c 'print dblocks' -c 'print fdblocks' -r " + partition .get_path(),
			output,
			error,
			true ) )
	{
		//blocksize
		if ( sscanf( output .c_str(), "blocksize = %Ld", &S ) != 1 )
			S = -1 ;

		//filesystem blocks
		index = output .find( "\ndblocks" ) ;
		if ( index > output .length() ||
		     sscanf( output .substr( index ) .c_str(), "\ndblocks = %Ld", &T ) != 1 )
			T = -1 ;

		//free blocks
		index = output .find( "\nfdblocks" ) ;
		if ( index > output .length() ||
		     sscanf( output .substr( index ) .c_str(), "\nfdblocks = %Ld", &N ) != 1 )
			N = -1 ;

		if ( T > -1 && N > -1 && S > -1 )
		{
			T = Utils::round( T * ( S / double(partition .sector_size) ) ) ;
			N = Utils::round( N * ( S / double(partition .sector_size) ) ) ;
			partition .set_sector_usage( T, N ) ;
		}

	}
	else
	{
		if ( ! output .empty() )
			partition .messages .push_back( output ) ;
		
		if ( ! error .empty() )
			partition .messages .push_back( error ) ;
	}
}

void xfs::read_label( Partition & partition )
{
	if ( ! Utils::execute_command( "xfs_db -r -c 'label' " + partition .get_path(), output, error, true ) )
	{
		partition.set_filesystem_label( Utils::regexp_label( output, "^label = \"(.*)\"" ) );
	}
	else
	{
		if ( ! output .empty() )
			partition .messages .push_back( output ) ;
		
		if ( ! error .empty() )
			partition .messages .push_back( error ) ;
	}
}

bool xfs::write_label( const Partition & partition, OperationDetail & operationdetail )
{
	Glib::ustring cmd = "" ;
	if( partition.get_filesystem_label().empty() )
		cmd = "xfs_admin -L -- " + partition .get_path() ;
	else
		cmd = "xfs_admin -L \"" + partition.get_filesystem_label() + "\" " + partition.get_path();
	return ! execute_command( cmd, operationdetail, EXEC_CHECK_STATUS );
}

void xfs::read_uuid( Partition & partition )
{
	if ( ! Utils::execute_command( "xfs_admin -u " + partition .get_path(), output, error, true ) )
	{
		partition .uuid = Utils::regexp_label( output, "^UUID[[:blank:]]*=[[:blank:]]*(" RFC4122_NONE_NIL_UUID_REGEXP ")" ) ;
	}
	else
	{
		if ( ! output .empty() )
			partition .messages .push_back( output ) ;

		if ( ! error .empty() )
			partition .messages .push_back( error ) ;
	}
}

bool xfs::write_uuid( const Partition & partition, OperationDetail & operationdetail )
{
	return ! execute_command( "xfs_admin -U generate " + partition.get_path(), operationdetail, EXEC_CHECK_STATUS );
}

bool xfs::create( const Partition & new_partition, OperationDetail & operationdetail )
{
	return ! execute_command( "mkfs.xfs -f -L \"" + new_partition.get_filesystem_label() + "\" " +
	                          new_partition.get_path(),
	                          operationdetail,
	                          EXEC_CHECK_STATUS|EXEC_CANCEL_SAFE );
}

bool xfs::resize( const Partition & partition_new, OperationDetail & operationdetail, bool fill_partition )
{
	bool success = true ;

	Glib::ustring mount_point ;
	if ( ! partition_new .busy )
	{
		mount_point = mk_temp_dir( "", operationdetail ) ;
		if ( mount_point.empty() )
			return false ;
		success &= ! execute_command( "mount -v -t xfs " + partition_new .get_path() + " " + mount_point,
		                              operationdetail, EXEC_CHECK_STATUS );
	}
	else
		mount_point = partition_new .get_mountpoint() ;

	if ( success )
	{
		success &= ! execute_command( "xfs_growfs " + mount_point, operationdetail, EXEC_CHECK_STATUS );

		if ( ! partition_new .busy )
			success &= ! execute_command( "umount -v " + mount_point, operationdetail, EXEC_CHECK_STATUS );
	}

	if ( ! partition_new .busy )
		rm_temp_dir( mount_point, operationdetail ) ;

	return success ;
}

bool xfs::copy( const Partition & src_part,
		Partition & dest_part,
		OperationDetail & operationdetail )
{
	bool success = true ;

	success &= ! execute_command( "mkfs.xfs -f " + dest_part.get_path(), operationdetail,
	                              EXEC_CHECK_STATUS|EXEC_CANCEL_SAFE );
	if ( ! success )
		return false ;

	Glib::ustring src_mount_point = mk_temp_dir( "src", operationdetail ) ;
	if ( src_mount_point .empty() )
		return false ;

	Glib::ustring dest_mount_point = mk_temp_dir( "dest", operationdetail ) ;
	if ( dest_mount_point .empty() )
	{
		rm_temp_dir( src_mount_point, operationdetail ) ;
		return false ;
	}

	success &= ! execute_command( "mount -v -t xfs -o noatime,ro " + src_part.get_path() +
	                              " " + src_mount_point, operationdetail, EXEC_CHECK_STATUS );

	if ( success )
	{
		success &= ! execute_command( "mount -v -t xfs " + dest_part.get_path() +
		                              " " + dest_mount_point, operationdetail, EXEC_CHECK_STATUS );

		if ( success )
		{
			success &= ! execute_command( "sh -c 'xfsdump -J - " + src_mount_point +
			                              " | xfsrestore -J - " + dest_mount_point + "'",
			                              operationdetail, EXEC_CHECK_STATUS|EXEC_CANCEL_SAFE );

			success &= ! execute_command( "umount -v " + dest_part.get_path(), operationdetail,
			                              EXEC_CHECK_STATUS );
		}

		success &= ! execute_command( "umount -v " + src_part.get_path(), operationdetail, EXEC_CHECK_STATUS );
	}

	rm_temp_dir( dest_mount_point, operationdetail ) ;

	rm_temp_dir( src_mount_point, operationdetail ) ;

	return success ;
}

bool xfs::check_repair( const Partition & partition, OperationDetail & operationdetail )
{
	return ! execute_command( "xfs_repair -v " + partition .get_path(), operationdetail,
	                          EXEC_CHECK_STATUS|EXEC_CANCEL_SAFE );
}

} //GParted
