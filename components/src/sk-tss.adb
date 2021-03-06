--
--  Copyright (C) 2014  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2014  Adrian-Ken Rueegsegger <ken@codelabs.ch>
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

package body SK.TSS
is

   -------------------------------------------------------------------------

   procedure Set_IST_Entry
     (TSS_Data : in out TSS_Type;
      Index    :        IST_Index_Type;
      Address  :        SK.Word64)
   is
   begin
      TSS_Data.IST (Index).Low  := SK.Word32'Mod (Address);
      TSS_Data.IST (Index).High := SK.Word32'Mod (Address / 2 ** 32);
   end Set_IST_Entry;

   -------------------------------------------------------------------------

   procedure Set_RSP
     (TSS_Data : in out TSS_Type;
      Level    :        RSP_Privilege_Level;
      Address  :        SK.Word64)
   is
   begin
      TSS_Data.RSPs (Level).Low  := SK.Word32'Mod (Address);
      TSS_Data.RSPs (Level).High := SK.Word32'Mod (Address / 2 ** 32);
   end Set_RSP;

end SK.TSS;
