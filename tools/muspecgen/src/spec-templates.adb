--
--  Copyright (C) 2013, 2014  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013, 2014  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with Ada.Exceptions;
with Ada.Directories;
with Ada.Direct_IO;

package body Spec.Templates
is

   use Ada.Strings.Unbounded;

   Store_Path : Unbounded_String := To_Unbounded_String ("./templates");

   -------------------------------------------------------------------------

   function Get_Size (Template : Template_Type) return Natural
   is
   begin
      return Length (Template.Data);
   end Get_Size;

   -------------------------------------------------------------------------

   function Load
     (Filename  : String;
      Use_Store : Boolean := True)
      return Template_Type
   is
      Path : Unbounded_String := To_Unbounded_String (Filename);
   begin
      if Use_Store then
         Path := To_String (Store_Path) & "/" & Path;
      end if;

      declare
         Size : constant Natural := Natural
           (Ada.Directories.Size (To_String (Path)));

         subtype Content_String is String (1 .. Size);
         package FIO is new Ada.Direct_IO (Content_String);

         Content    : Content_String;
         Input_File : FIO.File_Type;
      begin
         FIO.Open (File => Input_File,
                   Mode => FIO.In_File,
                   Name => To_String (Path),
                   Form => "shared=yes");
         FIO.Read (File => Input_File,
                   Item => Content);
         FIO.Close (File => Input_File);

         return T : Template_Type do
            T.Data := To_Unbounded_String (Content);
         end return;

      exception
         when others =>
            if FIO.Is_Open (File => Input_File) then
               FIO.Close (File => Input_File);
            end if;
            raise;
      end;

   exception
      when others =>
         raise IO_Error with "Unable to open template file '"
           & To_String (Path) & "'";
   end Load;

   -------------------------------------------------------------------------

   procedure Replace
     (Template : in out Template_Type;
      Pattern  :        String;
      Content  :        String)
   is
      Idx : Natural;
   begin
      Idx := Index (Source  => Template.Data,
                    Pattern => Pattern);
      if Idx = 0 then
         raise Pattern_Not_Found with "Pattern '" & Pattern
           & "' does not exist";
      end if;

      Replace_Slice (Source => Template.Data,
                     Low    => Idx,
                     High   => Idx + Pattern'Length - 1,
                     By     => Content);
   end Replace;

   -------------------------------------------------------------------------

   procedure Set_Template_Dir (Path : String)
   is
   begin
      Store_Path := To_Unbounded_String (Path);
   end Set_Template_Dir;

   -------------------------------------------------------------------------

   procedure Write
     (Template : Template_Type;
      Filename : String)
   is
      subtype Content_String is String (1 .. Length (Template.Data));
      package FIO is new Ada.Direct_IO (Content_String);

      Input_File : FIO.File_Type;
   begin
      if Ada.Directories.Exists (Name => Filename) then
         Ada.Directories.Delete_File (Name => Filename);
      end if;

      FIO.Create (File => Input_File,
                  Mode => FIO.Out_File,
                  Name => Filename);
      FIO.Write (File => Input_File,
                 Item => To_String (Template.Data));
      FIO.Close (File => Input_File);

   exception
      when E : others =>
         if FIO.Is_Open (File => Input_File) then
            FIO.Close (File => Input_File);
         end if;
         raise IO_Error with "Unable to write template to '"
           & Filename & "' - " & Ada.Exceptions.Exception_Message (X => E);
   end Write;

end Spec.Templates;