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

with Ada.Directories;
with Ada.Strings.Unbounded;

with Pack.Parser;
with Pack.File_Transforms;

with Pack.Command_Line.Test;

package body Transform_Tests
is

   use Ahven;
   use Pack;

   function U
     (Source : String)
      return Ada.Strings.Unbounded.Unbounded_String
      renames Ada.Strings.Unbounded.To_Unbounded_String;

   -------------------------------------------------------------------------

   procedure Default_Transform
   is
      use type Parser.File_Array;

      Files : Parser.File_Array
        := (1 => (Name    => U ("kernel|text"),
                  Path    => U ("obj1.o"),
                  Address => 16#0010_0000#,
                  Size    => 16#0001_3000#,
                  Offset  => 16#0010#,
                  Format  => Parser.Elf),
            2 => (Name    => U ("linux|acpi_rsdp"),
                  Path    => U ("linux_rsdp"),
                  Address => 16#0011_3000#,
                  Size    => 16#0001_3000#,
                  Offset  => 16#0001_b000#,
                  Format  => Parser.Acpi_Rsdp));
      Ref_Files : constant Parser.File_Array
        := (1 => (Name    => U ("kernel_text"),
                  Path    => U ("obj/obj1.o.bin"),
                  Address => 16#0010_0000#,
                  Size    => 16#0001_3000#,
                  Offset  => 16#0010#,
                  Format  => Parser.Elf),
            2 => (Name    => U ("linux_acpi_rsdp"),
                  Path    => U ("data/linux_rsdp"),
                  Address => 16#0011_3000#,
                  Size    => 16#0001_3000#,
                  Offset  => 16#0001_b000#,
                  Format  => Parser.Acpi_Rsdp));
   begin
      Command_Line.Test.Set_Input_Dir  (Path => "data");
      Command_Line.Test.Set_Output_Dir (Path => "obj");

      File_Transforms.Process (Files => Files);
      Assert (Condition => Ref_Files = Files,
              Message   => "Transformed files mismatch");

      Ada.Directories.Delete_File (Name => "obj/obj1.o.bin");
   end Default_Transform;

   -------------------------------------------------------------------------

   procedure Initialize (T : in out Testcase)
   is
   begin
      T.Set_Name (Name => "File transform tests");
      T.Add_Test_Routine
        (Routine => Default_Transform'Access,
         Name    => "Default transform");
   end Initialize;

end Transform_Tests;