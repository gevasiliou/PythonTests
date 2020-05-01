/* Copyright (C) 2004 Bart 'plors' Hakvoort
 * Copyright (C) 2008, 2009, 2010, 2011, 2012 Curtis Gedak
 * Copyright (C) 2013 Phillip Susi
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

#include "../include/Copy_Blocks.h"
#include <gtkmm/main.h>
#include <errno.h>

namespace GParted {

void copy_blocks::set_cancel( bool force )
{
	if ( force || cancel_safe )
		cancel = true;
}

copy_blocks::copy_blocks( const Glib::ustring & in_src_device,
			  const Glib::ustring & in_dst_device,
			  Sector src_start,
			  Sector dst_start,
			  Byte_Value in_length,
			  Byte_Value in_blocksize,
			  OperationDetail & in_operationdetail,
			  Byte_Value & in_total_done,
			  bool in_cancel_safe) :
	src_device( in_src_device ),
	dst_device ( in_dst_device ),
	length ( in_length ),
	blocksize ( in_blocksize ),
	operationdetail ( in_operationdetail ),
	total_done ( in_total_done ),
	offset_src ( src_start ),
	offset_dst ( dst_start ),
	cancel( false ),
	cancel_safe ( in_cancel_safe )
{
	operationdetail.signal_cancel.connect(
		sigc::mem_fun(*this, &copy_blocks::set_cancel));
	if (operationdetail.cancelflag)
		set_cancel( operationdetail.cancelflag == 2 );
}

bool copy_blocks::set_progress_info()
{
	Byte_Value done = llabs(this->done);
	OperationDetail &operationdetail = this->operationdetail.get_last_child().get_last_child();
	operationdetail.fraction = done / static_cast<double>( length );

	std::time_t time_remaining = Utils::round( (length - done) / ( done / timer_total.elapsed() ) );

	operationdetail.progress_text =
		String::ucompose( /*TO TRANSLATORS: looks like  1.00 MiB of 16.00 MiB copied (00:01:59 remaining) */
				  _("%1 of %2 copied (%3 remaining)"),
				  Utils::format_size( done, 1 ),
				  Utils::format_size( length,1 ),
				  Utils::format_time( time_remaining ) );

	operationdetail.set_description(
		String::ucompose( /*TO TRANSLATORS: looks like  1.00 MiB of 16.00 MiB copied */
				_("%1 of %2 copied"),
				Utils::format_size( done, 1 ), Utils::format_size( length, 1 ) ),
		FONT_ITALIC );
	return false;
}

static bool mainquit(copy_blocks *cb)
{
	while ( Gtk::Main::events_pending() )
		Gtk::Main::iteration();
	Gtk::Main::quit();
	return false;
}

static gboolean _set_progress_info( gpointer data )
{
	copy_blocks *cb = (copy_blocks *)data;
	return cb->set_progress_info();
}

void copy_blocks::copy_thread()
{
	if ( ped_device_open( lp_device_src ) &&
	     (lp_device_src == lp_device_dst || ped_device_open( lp_device_dst ) ) )
	{
		Byte_Value src_sector_size = lp_device_src ->sector_size;
		Byte_Value dst_sector_size = lp_device_dst ->sector_size;

		//Handle situation where we need to perform the copy beginning
		//  with the end of the partition and finishing with the start.
		if ( offset_src < offset_dst )
		{
			blocksize -= 2*blocksize;
			done -= 2*done;
			offset_src += length / src_sector_size;
			/* Handle situation where src sector size is smaller than dst sector size and an additional partial dst sector is required. */
			offset_dst += (length + (dst_sector_size - 1)) / dst_sector_size;
		}
		success = true;
	} else success = false;

	ped_device_sync( lp_device_dst );

	if ( success && done != 0 )
	{
		Byte_Value b = blocksize;
		blocksize = done;
		done = 0;
		/* copy partial block first */
		copy_block();
		blocksize = b;
	}
	Glib::Timer timer_progress_timeout;
	while( success && llabs( done ) < length )
	{
		copy_block();
		if ( timer_progress_timeout .elapsed() >= 0.5 )
		{
			g_idle_add( _set_progress_info, this );
			timer_progress_timeout.reset();
		}
	}
	total_done += llabs( done );

	//close and destroy the devices..
	ped_device_close( lp_device_src );
	ped_device_destroy( lp_device_src );

	if ( src_device != dst_device )
	{
		ped_device_close( lp_device_dst );
		ped_device_destroy( lp_device_dst );
	}

	//set progress bar current info on completion
	g_idle_add( _set_progress_info, this );
	g_idle_add( (GSourceFunc)mainquit, this );
}

bool copy_blocks::copy()
{
	if ( blocksize > length )
		blocksize = length;

	operationdetail.add_child( OperationDetail(
			/*TO TRANSLATORS: looks like  copy 16.00 MiB using a block size of 1.00 MiB */
			String::ucompose( _("copy %1 using a block size of %2"),
			                  Utils::format_size( length, 1 ),
			                  Utils::format_size( blocksize, 1 ) ) ) );

	done = length % blocksize;

	lp_device_src = ped_device_get( src_device.c_str() );
	lp_device_dst = src_device != dst_device ? ped_device_get( dst_device.c_str() ) : lp_device_src;
	//add an empty sub which we will constantly update in the loop
	operationdetail.get_last_child().add_child( OperationDetail( "", STATUS_NONE ) );
	buf = static_cast<char *>( malloc( llabs( blocksize ) ) );
	if ( buf )
	{
		Glib::Thread::create( sigc::mem_fun( *this, &copy_blocks::copy_thread ),
				      false );
		Gtk::Main::run();
		if (done == length || !success)
		{
			//reset fraction to -1 to make room for a new one (or a pulsebar)
			operationdetail.get_last_child().get_last_child().fraction = -1;

			//final description
			operationdetail.get_last_child().get_last_child().set_description(
				String::ucompose( /*TO TRANSLATORS: looks like  1.00 MiB of 16.00 MiB copied */
						  _("%1 of %2 copied"),
						  Utils::format_size( llabs( done ), 1 ),
						  Utils::format_size( length, 1 ) ),
				FONT_ITALIC );

			if ( !success && !error_message.empty() )
				operationdetail.get_last_child().get_last_child().add_child(
					OperationDetail( error_message, STATUS_NONE, FONT_ITALIC ) );
		}
		free( buf ) ;
	}
	else
		error_message = Glib::strerror( errno );

	operationdetail.get_last_child().set_status( success ? STATUS_SUCCES : STATUS_ERROR );
	return success;
}

void copy_blocks::copy_block()
{
	Byte_Value sector_size_src = lp_device_src ->sector_size;
	Byte_Value sector_size_dst = lp_device_dst ->sector_size;

	//Handle case where src and dst sector sizes are different.
	//    E.g.,  5 sectors x 512 bytes/sector = ??? 2048 byte sectors
	Sector num_blocks_src = (llabs(blocksize) + (sector_size_src - 1) ) / sector_size_src;
	Sector num_blocks_dst = (llabs(blocksize) + (sector_size_dst - 1) ) / sector_size_dst;

	//Handle situation where we are performing copy operation beginning
	//  with the end of the partition and finishing with the start.
	if ( blocksize < 0 )
	{
		offset_src += (blocksize / sector_size_src);
		offset_dst += (blocksize / sector_size_dst);
	}

	if ( cancel )
	{
		error_message = _("Operation Canceled");
		success = false;
		return;
	}

	if ( blocksize != 0 )
	{
		if ( ped_device_read( lp_device_src, buf, offset_src, num_blocks_src ) )
		{
			if ( ped_device_write( lp_device_dst, buf, offset_dst, num_blocks_dst ) )
				success = true;
			else {
				error_message = String::ucompose( _("Error while writing block at sector %1"), offset_dst );
				success = false;
			}
		}
		else
			error_message = String::ucompose( _("Error while reading block at sector %1"), offset_src ) ;
	}
	if ( blocksize > 0 )
	{
		offset_src += (blocksize / sector_size_src);
		offset_dst += (blocksize / sector_size_dst);
	}
	if( success )
		done += blocksize;
}

} // namespace GParted
