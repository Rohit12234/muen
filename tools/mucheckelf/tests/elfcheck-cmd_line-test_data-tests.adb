--  This package has been generated automatically by GNATtest.
--  You are allowed to add your code to the bodies of test routines.
--  Such changes will be kept during further regeneration of this file.
--  All code placed outside of test routine bodies will be lost. The
--  code intended to set up and tear down the test environment should be
--  placed into Elfcheck.Cmd_Line.Test_Data.

with AUnit.Assertions; use AUnit.Assertions;
with System.Assertions;

package body Elfcheck.Cmd_Line.Test_Data.Tests is


--  begin read only
   procedure Test_Init (Gnattest_T : in out Test);
   procedure Test_Init_a69a58 (Gnattest_T : in out Test) renames Test_Init;
--  id:2.2/a69a5871ab5eef40/Init/1/0/
   procedure Test_Init (Gnattest_T : in out Test) is
   --  elfcheck-cmd_line.ads:27:4:Init
--  end read only

      pragma Unreferenced (Gnattest_T);

      use type Ada.Strings.Unbounded.Unbounded_String;

      ----------------------------------------------------------------------

      procedure Invalid_Switch
      is
         Args        : aliased GNAT.OS_Lib.Argument_List
           := (1 => new String'("-x"));
         Test_Parser : GNAT.Command_Line.Opt_Parser;
      begin
         GNAT.Command_Line.Initialize_Option_Scan
           (Parser       => Test_Parser,
            Command_Line => Args'Unchecked_Access);

         Parser := Test_Parser;

         begin
            Init (Description => "Test run");
            for A in Args'Range loop
               GNAT.OS_Lib.Free (X => Args (A));
            end loop;
            Assert (Condition => False,
                    Message   => "Exception expected");

         exception
            when Invalid_Cmd_Line =>
               null;
         end;

         for A in Args'Range loop
            GNAT.OS_Lib.Free (X => Args (A));
         end loop;
      end Invalid_Switch;

      ----------------------------------------------------------------------

      procedure Null_Argument
      is
         Args        : aliased GNAT.OS_Lib.Argument_List
           := (1 => new String'("file"));
         Test_Parser : GNAT.Command_Line.Opt_Parser;
      begin
         GNAT.Command_Line.Initialize_Option_Scan
           (Parser       => Test_Parser,
            Command_Line => Args'Unchecked_Access);

         Parser := Test_Parser;

         begin
            Init (Description => "Test run");
            for A in Args'Range loop
               GNAT.OS_Lib.Free (X => Args (A));
            end loop;
            Assert (Condition => False,
                    Message   => "Exception expected");

         exception
            when Invalid_Cmd_Line =>
               null;
         end;

         for A in Args'Range loop
            GNAT.OS_Lib.Free (X => Args (A));
         end loop;
      end Null_Argument;

      ----------------------------------------------------------------------

      procedure Positive_Test
      is
         Args        : aliased GNAT.OS_Lib.Argument_List
           := (1 => new String'("data/test_policy.xml"),
               2 => new String'("elf_binary"));
         Test_Parser : GNAT.Command_Line.Opt_Parser;
      begin
         GNAT.Command_Line.Initialize_Option_Scan
           (Parser       => Test_Parser,
            Command_Line => Args'Unchecked_Access);

         Parser := Test_Parser;

         Init (Description => "Test run");

         for A in Args'Range loop
            GNAT.OS_Lib.Free (X => Args (A));
         end loop;

         Assert (Condition => Policy = "data/test_policy.xml",
                 Message   => "Policy mismatch");
         Assert (Condition => ELF_Binary = "elf_binary",
                 Message   => "ELF binary mismatch");
      end;
   begin
      Invalid_Switch;
      Null_Argument;
      Positive_Test;
--  begin read only
   end Test_Init;
--  end read only


--  begin read only
   procedure Test_Get_Policy (Gnattest_T : in out Test);
   procedure Test_Get_Policy_aac0d6 (Gnattest_T : in out Test) renames Test_Get_Policy;
--  id:2.2/aac0d695aae58756/Get_Policy/1/0/
   procedure Test_Get_Policy (Gnattest_T : in out Test) is
   --  elfcheck-cmd_line.ads:30:4:Get_Policy
--  end read only

      pragma Unreferenced (Gnattest_T);

      use Ada.Strings.Unbounded;

      Ref : constant Unbounded_String
        := To_Unbounded_String ("testpolicy.xml");
   begin
      Policy := Ref;
      Assert (Condition => Get_Policy = Ref,
              Message   => "Policy mismatch");
--  begin read only
   end Test_Get_Policy;
--  end read only


--  begin read only
   procedure Test_Get_ELF_Binary (Gnattest_T : in out Test);
   procedure Test_Get_ELF_Binary_bbfe6b (Gnattest_T : in out Test) renames Test_Get_ELF_Binary;
--  id:2.2/bbfe6be737e0de8d/Get_ELF_Binary/1/0/
   procedure Test_Get_ELF_Binary (Gnattest_T : in out Test) is
   --  elfcheck-cmd_line.ads:33:4:Get_ELF_Binary
--  end read only

      pragma Unreferenced (Gnattest_T);

      use Ada.Strings.Unbounded;

      Ref : constant Unbounded_String
        := To_Unbounded_String ("my_binary");
   begin
      ELF_Binary := Ref;
      Assert (Condition => Get_ELF_Binary = Ref,
              Message   => "ELF binary mismatch");

--  begin read only
   end Test_Get_ELF_Binary;
--  end read only

end Elfcheck.Cmd_Line.Test_Data.Tests;
