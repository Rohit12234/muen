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

with Skp;

package SK.CPU_Registry
with
   Abstract_State => State,
   Initializes    => State
is

   --  Register CPU with given CPU ID and local APIC ID.
   procedure Register
     (CPU_ID  : Skp.CPU_Range;
      APIC_ID : SK.Byte)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ (CPU_ID, APIC_ID));

   --  Return APIC ID for CPU with given CPU ID.
   function Get_APIC_ID (CPU_ID : Skp.CPU_Range) return SK.Byte
   with
      Global => State;

end SK.CPU_Registry;
