/*  Copyright (C) 2013 Phillip Susi
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

#ifndef GPARTED_COPY_BLOCKS_H
#define GPARTED_COPY_BLOCKS_H

#include "../include/Operation.h"
#include <parted/parted.h>

namespace GParted {

class copy_blocks {
	const Glib::ustring & src_device;
	const Glib::ustring & dst_device;
	Byte_Value length;
	Byte_Value blocksize;
	OperationDetail &operationdetail;
	Byte_Value & total_done;
	char *buf;
	Byte_Value done;
	PedDevice *lp_device_src;
	PedDevice *lp_device_dst;
	Sector offset_src;
	Sector offset_dst;
	Glib::Timer timer_total;
	bool success;
	Glib::ustring error_message;
	void copy_thread();
	bool cancel;
	bool cancel_safe;
	void set_cancel( bool force );
public:
	bool set_progress_info();
	copy_blocks( const Glib::ustring & in_src_device,
		     const Glib::ustring & in_dst_device,
		     Sector src_start,
		     Sector dst_start,
		     Byte_Value in_length,
		     Byte_Value in_blocksize,
		     OperationDetail & in_operationdetail,
		     Byte_Value & in_total_done,
		     bool cancel_safe );
	bool copy();
	void copy_block();
};

} // namespace GParted

#endif /* GPARTED_COPY_BLOCKS_H */
