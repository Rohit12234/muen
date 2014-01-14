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

with Interfaces;

with DOM.Core;

with Mutools.Utils;

package Spec.Utils
is

   --  Converts a given list of bitfields to their corresponding numeric value.
   generic
      --  Enumration type specifying all bitfields.
      type Bitfield_Type is (<>);

      type Mapping_Type is array (Bitfield_Type)
        of Mutools.Utils.Unsigned_64_Pos;

      --  Mapping of fields to bit position.
      Map : Mapping_Type;
   function To_Number
     (Fields : DOM.Core.Node_List)
      return Interfaces.Unsigned_64;

end Spec.Utils;