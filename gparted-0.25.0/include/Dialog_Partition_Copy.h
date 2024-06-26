/* Copyright (C) 2004 Bart
 * Copyright (C) 2010 Curtis Gedak
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

#ifndef GPARTED_DIALOG_PARTITION_COPY_H
#define GPARTED_DIALOG_PARTITION_COPY_H

#include "../include/Dialog_Base_Partition.h"

namespace GParted
{

class Dialog_Partition_Copy : public Dialog_Base_Partition
{
public:
	Dialog_Partition_Copy( const FS & fs, const Partition & selected_partition,
	                       const Partition & copied_partition );

	const Partition & Get_New_Partition( Byte_Value sector_size );

private:
	void set_data( const Partition & selected_partition, const Partition & copied_partition );
};

}//GParted

#endif /* GPARTED_DIALOG_PARTITION_COPY_H */
