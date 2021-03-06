--
--  Copyright (C) 2013  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with SK.Utils;

package body SK.Console
is

   -------------------------------------------------------------------------

   procedure Init
   is
   begin
      Initialize;
   end Init;

   -------------------------------------------------------------------------

   procedure New_Line
   is
   begin
      Output_New_Line;
   end New_Line;

   -------------------------------------------------------------------------

   procedure Put_Byte (Item : Byte)
   is
      subtype Byte_Range is Positive range 1 .. 2;
      subtype Byte_String is String (Byte_Range);

      Str : Byte_String := Byte_String'(others => '0');
   begin
      Utils.To_Hex (Item   => Word64 (Item),
                    Buffer => Str);
      Put_String (Item => Str);
   end Put_Byte;

   -------------------------------------------------------------------------

   procedure Put_Char (Item : Character)
   is
   begin
      Output_Char (Item => Item);
   end Put_Char;

   -------------------------------------------------------------------------

   procedure Put_Line (Item : String)
   is
   begin
      Put_String (Item => Item);
      New_Line;
   end Put_Line;

   -------------------------------------------------------------------------

   procedure Put_String (Item : String)
   is
   begin
      for I in Item'Range loop
         Put_Char (Item => Item (I));
      end loop;
   end Put_String;

   -------------------------------------------------------------------------

   procedure Put_Word16 (Item : Word16)
   is
      subtype Word16_Range is Positive range 1 .. 4;
      subtype Word16_String is String (Word16_Range);

      Str : Word16_String := Word16_String'(others => '0');
   begin
      Utils.To_Hex (Item   => Word64 (Item),
                    Buffer => Str);
      Put_String (Item => Str);
   end Put_Word16;

   -------------------------------------------------------------------------

   procedure Put_Word32 (Item : Word32)
   is
      subtype Word32_Range is Positive range 1 .. 8;
      subtype Word32_String is String (Word32_Range);

      Str : Word32_String := Word32_String'(others => '0');
   begin
      Utils.To_Hex (Item   => Word64 (Item),
                    Buffer => Str);
      Put_String (Item => Str);
   end Put_Word32;

   -------------------------------------------------------------------------

   procedure Put_Word64 (Item : Word64)
   is
      subtype Word64_Range is Positive range 1 .. 16;
      subtype Word64_String is String (Word64_Range);

      Str : Word64_String := Word64_String'(others => '0');
   begin
      Utils.To_Hex (Item   => Item,
                    Buffer => Str);
      Put_String (Item => Str);
   end Put_Word64;

end SK.Console;
