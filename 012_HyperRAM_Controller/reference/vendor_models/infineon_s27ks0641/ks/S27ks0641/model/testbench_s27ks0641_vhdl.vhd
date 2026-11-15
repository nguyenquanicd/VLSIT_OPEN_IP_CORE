-------------------------------------------------------------------------------
--  File name : testbench_s27ks0641_vhdl.vhd
-------------------------------------------------------------------------------
--  Copyright (C) 2015 Spansion, LLC.
--
--  MODIFICATION HISTORY :
--
--  version:  |   author:       | mod date: |   changes made:
--    V1.0      M.Stojanovic     15 June 24     Initial release
--    V1.1      M.Stojanovic     16 Mar  01     Changed tDSV time (bug #500 fixed)
--    V1.2      S.Stevanovic     16 Oct  21     Added self-refresh feature and
--              M.Stojanovic     16 Oct  21     Added new registers
--    V1.3      M.Stojanovic     16 Nov  15     Corrected burst length behavior
--    V1.4      S.Stevanovic     16 Nov  25     Fixing issue for BurstDelay = 3
--    V1.5      M.Stojanovic     18 Feb  14     Update to datasheet 001-97964 Rev.*K
--    V1.6      M.Stojanovic     18 Mar  12     Corrected wrapped burst (bug #14 fixed)
--
-------------------------------------------------------------------------------
--  PART DESCRIPTION:
--
--  Description:
--            Generic test enviroment for verification of Spansion RPC PSRAM
--            VITAL model s27ks0641
--
-------------------------------------------------------------------------------
--  Comments :
--      For correct simulation, simulator resolution should be set to 1ps
--
-------------------------------------------------------------------------------
--  Known Bugs:
--
-------------------------------------------------------------------------------
LIBRARY IEEE;
    USE IEEE.std_logic_1164.ALL;
    USE IEEE.VITAL_timing.ALL;
    USE IEEE.VITAL_primitives.ALL;
    USE STD.textio.ALL;

LIBRARY FMF;
    USE FMF.gen_utils.all;
    USE FMF.conversions.all;

LIBRARY work;
    USE work.spansion_tc_pkg.all;

-------------------------------------------------------------------------------
-- ENTITY DECLARATION
-------------------------------------------------------------------------------
ENTITY testbench_s27ks0641_vhdl IS
    GENERIC (
        -- Set test environment - device protection mode
         MODE : DEVICE_MODE := RAND_LATENCY
--          MODE : DEVICE_MODE := VARIABLE_LATENCY
            );
END testbench_s27ks0641_vhdl;

-------------------------------------------------------------------------------
-- ARCHITECTURE DECLARATION
-------------------------------------------------------------------------------
ARCHITECTURE vhdl_behavioral_static_memory_allocation of testbench_s27ks0641_vhdl IS
COMPONENT s27ks0641
    GENERIC (
        -- tipd delays: interconnect path delays
        tipd_DQ0             : VitalDelayType01 := VitalZeroDelay01; --
        tipd_DQ1             : VitalDelayType01 := VitalZeroDelay01; --
        tipd_DQ2             : VitalDelayType01 := VitalZeroDelay01; --
        tipd_DQ3             : VitalDelayType01 := VitalZeroDelay01; -- data
        tipd_DQ4             : VitalDelayType01 := VitalZeroDelay01; -- lines
        tipd_DQ5             : VitalDelayType01 := VitalZeroDelay01; --
        tipd_DQ6             : VitalDelayType01 := VitalZeroDelay01; --
        tipd_DQ7             : VitalDelayType01 := VitalZeroDelay01; --

        tipd_CSNeg           : VitalDelayType01 := VitalZeroDelay01; --
        tipd_CK              : VitalDelayType01 := VitalZeroDelay01; --
        tipd_CKNeg           : VitalDelayType01 := VitalZeroDelay01; --
        tipd_RESETNeg        : VitalDelayType01 := VitalZeroDelay01; --
        tipd_RWDS            : VitalDelayType01 := VitalZeroDelay01; --

        --tpd delays
        tpd_CSNeg_RWDS       : VitalDelayType01Z := UnitDelay01Z;   --tDSZ
        tpd_CK_RWDS          : VitalDelayType01Z := UnitDelay01Z;   --tCKDS

        tpd_CSNeg_DQ0        : VitalDelayType01Z := UnitDelay01Z;   --tOZ
        tpd_CK_DQ0           : VitalDelayType01Z := UnitDelay01Z;   --tCKD

        --tsetup values
        tsetup_CSNeg_CK      : VitalDelayType    := UnitDelay;  --tCSS edge /
        tsetup_DQ0_CK        : VitalDelayType := UnitDelay;  --tIS

        --thold values
        thold_CSNeg_CK       : VitalDelayType := UnitDelay;  --tCSH  edge \
        thold_DQ0_CK         : VitalDelayType := UnitDelay;  --tIH
        thold_CSNeg_RESETNeg : VitalDelayType := UnitDelay; -- tRH

        --trecovery value
        trecovery_CSNeg_CK_posedge_negedge : VitalDelayType := UnitDelay; --tRWR

        --tpw values: pulse width
        tpw_CK_negedge       : VitalDelayType := UnitDelay; --tCL
        tpw_CK_posedge       : VitalDelayType := UnitDelay; --tCH
        tpw_CSNeg_posedge    : VitalDelayType := UnitDelay; --tCSHI
        tpw_RESETNeg_negedge : VitalDelayType := UnitDelay; --tRP

        --tperiod values
        tperiod_CK      :VitalDelayType := UnitDelay;

        --tdevice values: values for internal delays
        -- power-on reset
        tdevice_VCS              :VitalDelayType := 150 us;
        -- Deep Power Down to Idle wake up time
        tdevice_DPD              :VitalDelayType := 150 us;
        -- Warm HW reset
        tdevice_RPH              :VitalDelayType := 400 ns;
        --  Refresh time
        tdevice_REF166           :VitalDelayType :=  36 ns;
        --  Page Open Time
        tdevice_PO166            :VitalDelayType :=  36 ns;
        -- CSNeg Maximum Low Time
        tdevice_CSM              :VitalDelayType :=   4 us;

        -- generic control parameters
        InstancePath        :STRING  := DefaultInstancePath;
        TimingChecksOn      :BOOLEAN := DefaultTimingChecks;
        MsgOn               :BOOLEAN := DefaultMsgOn;
        XOn                 :BOOLEAN := DefaultXOn;

        -- memory file to be loaded
        mem_file_name       : STRING    := "s27ks0641.mem";
        UserPreload         : BOOLEAN   := FALSE;
        SRManualOverride    : INTEGER   := 1;
        RefreshPeriod       : INTEGER   := 2;

        -- For FMF SDF technology file usage
        TimingModel          : STRING
    );

    PORT (
        DQ7             : INOUT std_logic := 'U'; --
        DQ6             : INOUT std_logic := 'U'; --
        DQ5             : INOUT std_logic := 'U'; --
        DQ4             : INOUT std_logic := 'U'; --
        DQ3             : INOUT std_logic := 'U'; --
        DQ2             : INOUT std_logic := 'U'; --
        DQ1             : INOUT std_logic := 'U'; --
        DQ0             : INOUT std_logic := 'U'; --

        CSNeg           : IN    std_ulogic := 'U';
        CK              : IN    std_ulogic := 'U';
        CKNeg           : IN    std_ulogic := 'U';
        RESETNeg        : IN    std_ulogic := 'U';
        RWDS            : INOUT std_logic  := 'U'
    );
    END COMPONENT;

FOR ALL: s27ks0641 USE ENTITY WORK.s27ks0641;

    ---------------------------------------------------------------------------
    --memory configuration
    ---------------------------------------------------------------------------
    CONSTANT MaxData        :NATURAL := 16#FF#;
    CONSTANT MemSize        :NATURAL := 16#7FFFFF#;
    CONSTANT HiAddrBit      :NATURAL := 21;
    ---------------------------------------------------------------------------
    --model configuration
    ---------------------------------------------------------------------------
    CONSTANT mem_file         : STRING  := "s27ks0641.mem";
    CONSTANT half_period_166  : time    := 3.1 ns; -- 1/(2*166MHz)
    CONSTANT UserPreload      : BOOLEAN := TRUE;
    CONSTANT TimingModel      : STRING  := "S27KS0641DPBHI020";
    CONSTANT RefreshPeriod    : INTEGER := 2;
    CONSTANT SRManualOverride : INTEGER := 1;
    ---------------------------------------------------------------------------

     --Flash Memory Array
    TYPE MemArr IS ARRAY (0 TO (MemSize + 1)) OF INTEGER RANGE -1 TO MaxData;
    SHARED VARIABLE Mem     : MemArr   := (OTHERS => MaxData);

    CONSTANT ID_Register_0 : std_logic_vector(15 downto 0) := "0001111111110001";
    CONSTANT ID_Register_1 : std_logic_vector(15 downto 0) := (OTHERS => '0');
    SIGNAL Config_reg_0 : std_logic_vector(15 downto 0) := "1000111100011111";
    SIGNAL Config_reg_1 : std_logic_vector(15 downto 0) := "0000000000000010";

    SIGNAL check_err       :   std_logic := '0'; -- Active high on error
    SIGNAL ErrorInTest     :   std_logic := '0';

    --DUT port
    SIGNAL T_DQ         : std_logic_vector(7 downto 0) := (OTHERS => 'U');
    SIGNAL T_CSNeg      : std_ulogic := 'U';
    SIGNAL T_CK         : std_ulogic := 'U';
    SIGNAL T_CKNeg      : std_ulogic := 'U';
    SIGNAL T_RESETNeg   : std_ulogic := '1';
    SIGNAL T_RWDS       : std_logic  := 'U';

    SHARED VARIABLE CA_bits      : std_logic_vector(47 downto 0);
    SHARED VARIABLE BurstDelay   : NATURAL RANGE 0 TO 6;
    SHARED VARIABLE RefreshDelay : NATURAL RANGE 0 TO 6;
    SHARED VARIABLE BurstLength  : NATURAL RANGE 0 TO 128;
    SIGNAL half_period           : TIME  := half_period_166;
    SIGNAL half_period_tmp       : TIME;
    SIGNAL change_ck             : std_logic := '0';

    SHARED VARIABLE WrAddress       : NATURAL RANGE 0 to MemSize+1  :=0;
    SHARED VARIABLE WrAddress_Start : NATURAL RANGE 0 to MemSize  :=0;
    SHARED VARIABLE WrAddress_slv   : std_logic_vector(HiAddrBit downto 0);

    SHARED VARIABLE WR_ADDR_WRAP    : BOOLEAN := FALSE;
    SHARED VARIABLE WR_LEGACY_WRAP  : BOOLEAN := FALSE;
    SHARED VARIABLE WR_CONTINUOUS   : BOOLEAN := FALSE;

    SHARED VARIABLE ClockEnable      : BOOLEAN := FALSE;

    SHARED VARIABLE cmd_seq   : cmd_seq_type;

    SIGNAL data_num    : NATURAL RANGE 0 TO MemSize;
    SIGNAL cmd             : cmd_type := idle;

    SIGNAL Tseries     : NATURAL;
    SIGNAL Tcase       : NATURAL;

    SHARED VARIABLE ts_cnt  :   NATURAL RANGE 1 TO 40:=1; -- testseries counter
    SHARED VARIABLE tc_cnt  :   NATURAL RANGE 0 TO 15:=0; -- testcase counter

    ---------------------------------------------------------------------------
    -- self refresh logic
    ---------------------------------------------------------------------------
    TYPE self_refresh_type  IS (SF_POWER_OFF  ,
                                SF_POWER_ON   ,
                                SF_ACC_DLY    ,
                                SF_RFRSH_DLY  ,
                                SF_RFRSH_DLY_1,
                                SF_RESET      );

    CONSTANT tdevice_REF166 : time        := 36 ns;
    SIGNAL tdevice_REFINTV  : time        := 64 ms;
    SIGNAL tdevice_ROWREF   : time        := RefreshPeriod*tdevice_REF166;

    SIGNAL PoweredUp                      : std_logic := '0';
    SIGNAL sf_nxt_state, sf_curr_state    : self_refresh_type := SF_POWER_OFF;
    SIGNAL RFH_in, RFH_out, RowRefreshing,
           RowRfrshDly                    : std_logic := '0';
    SIGNAL REFCOLL_ACTIV                  : std_logic := '0';
    SIGNAL self_refresh_en                : std_logic := '0';

    BEGIN

        DUT : s27ks0641
            GENERIC MAP (
            -- tipd delays: interconnect path delays
            tipd_DQ0             => VitalZeroDelay01, --
            tipd_DQ1             => VitalZeroDelay01, --
            tipd_DQ2             => VitalZeroDelay01, --
            tipd_DQ3             => VitalZeroDelay01, -- data
            tipd_DQ4             => VitalZeroDelay01, -- lines
            tipd_DQ5             => VitalZeroDelay01, --
            tipd_DQ6             => VitalZeroDelay01, --
            tipd_DQ7             => VitalZeroDelay01, --

            tipd_CSNeg           => VitalZeroDelay01, --
            tipd_CK              => VitalZeroDelay01, --
            tipd_CKNeg           => VitalZeroDelay01, --
            tipd_RESETNeg        => VitalZeroDelay01, --
            tipd_RWDS            => VitalZeroDelay01, --

            --tpd delays
            tpd_CSNeg_RWDS       => UnitDelay01Z,   --tDSZ
            tpd_CK_RWDS          => UnitDelay01Z,   --tCKDS

            tpd_CSNeg_DQ0        => UnitDelay01Z,   --tOZ
            tpd_CK_DQ0           => UnitDelay01Z,   --tCKD

            --tsetup values
            tsetup_CSNeg_CK      => UnitDelay,  --tCSS edge /
            tsetup_DQ0_CK        => UnitDelay,  --tIS

            --thold values
            thold_CSNeg_CK       => UnitDelay, --tCSH  edge \
            thold_DQ0_CK         => UnitDelay,  --tIH
            thold_CSNeg_RESETNeg => UnitDelay, -- tRH

            --trecovery value
            trecovery_CSNeg_CK_posedge_negedge => UnitDelay, --tRWR

            --tpw values: pulse width
            tpw_CK_negedge       => UnitDelay, --tCL
            tpw_CK_posedge       => UnitDelay, --tCH
            tpw_CSNeg_posedge    => UnitDelay, --tCSHI
            tpw_RESETNeg_negedge => UnitDelay, --tRP

            --tperiod values
            tperiod_CK           => UnitDelay, --tCK

            --tdevice values: values for internal delays
            -- power-on reset
            tdevice_VCS          => 150 us,
            -- Deep Power Down to Idle wake up time
            tdevice_DPD          => 150 us,
            -- Duration of reset operation
            tdevice_RPH          => 400 ns,
            -- Refresh time
            tdevice_REF166       => 36 ns,
            -- Page Open time
            tdevice_PO166        => 36 ns,
            -- CSNeg Maximum Low Time
            tdevice_CSM          =>  4 us,

            -- generic control parameters
            InstancePath        => DefaultInstancePath,
            TimingChecksOn      => TRUE,
            MsgOn               => DefaultMsgOn,
            XOn                 => DefaultXOn,

            -- memory file to be loaded
            UserPreload         => UserPreload,
            mem_file_name       => "s27ks0641.mem",

            SRManualOverride    => SRManualOverride,
            RefreshPeriod       => RefreshPeriod,

            -- For FMF SDF technology file usage
            TimingModel         =>  "S27KS0641DPBHI020"
        )

        PORT MAP(
            DQ7        => T_DQ(7), --
            DQ6        => T_DQ(6), --
            DQ5        => T_DQ(5), --
            DQ4        => T_DQ(4), --
            DQ3        => T_DQ(3), --
            DQ2        => T_DQ(2), --
            DQ1        => T_DQ(1), --
            DQ0        => T_DQ(0), --

            CSNeg      => T_CSNeg,
            CK         => T_CK,
            CKNeg      => T_CKNeg,
            RESETNeg   => T_RESETNeg,
            RWDS       => T_RWDS
        );

    half_period <= half_period_tmp WHEN  change_ck = '1' ELSE
                   half_period_166 WHEN
                            ((TimingModel = "S27KS0641DPBHI020") OR
                             (TimingModel = "s27ks0641dpbhi020"));

    PoweredUp <= '1' AFTER 150 us;--tdevice_VCS;

    clk_generation: PROCESS(T_CK, T_CSNeg)
    BEGIN
        IF T_CSNeg = '1' THEN
            T_CK    <= '0';
            T_CKNeg <= '1';
        ELSIF (ClockEnable) THEN
            T_CK    <= NOT T_CK    AFTER half_period;
            T_CKNeg <= NOT T_CKNeg AFTER half_period;
        END IF;
    END PROCESS clk_generation;

    ----------------------------------------------------------------------------
    --At the end of the simulation, if not ErrorInTest there were no errors
    ----------------------------------------------------------------------------
    err_ctrl : PROCESS ( check_err  )
    BEGIN
        IF check_err = '1' THEN
            ErrorInTest <= '1';
        END IF;
    END PROCESS err_ctrl;

    ---------------------------------------------------------------------------
    -- model self refresh in TB so that we may check model behavior
    ---------------------------------------------------------------------------
--     PoweredUp <= '1' AFTER tdevice_VCS;
    ---------------------------------------------------------------------------
    --self refresh types
    ---------------------------------------------------------------------------

    tdevice_ROWREF <= (RefreshPeriod*tdevice_REF166) WHEN (SRManualOverride = 1) ELSE
                      (tdevice_REFINTV / 8192);

    tdevice_REFINTV <= (16 ms) WHEN ((TimingModel(14) = 'V') OR
                                    (TimingModel(14) = 'v')) ELSE
                       (64 ms);

    self_refresh_en_process : PROCESS (T_CSNeg, Config_reg_0)
    BEGIN
        IF ((T_CSNeg = '1') AND (Config_reg_0(3) = '0')) THEN
            self_refresh_en <= '1';
        ELSIF ((T_CSNeg = '1') AND (Config_reg_0(3) = '1')) THEN
            self_refresh_en <= '0';
        END IF;
    END PROCESS self_refresh_en_process;

    -- Row Refresh inteval timer. Generate refresh start event periodically at
    -- Arrea refresh interval / 8192
    RefreshInterval_process : PROCESS (RFH_out, self_refresh_en)
    BEGIN
        IF rising_edge(self_refresh_en) THEN
            RFH_in <= '1';
        ELSIF (self_refresh_en = '1') THEN
            IF rising_edge(RFH_out) THEN
                RFH_in <= '0', '1' after (tdevice_ROWREF - 36 ns);--(tdevice_ROWREF - tdevice_REF166);
            END IF;
        ELSE
            RFH_in <= '0';
        END IF;
    END PROCESS RefreshInterval_process;

    -- Timing control
    -- Refresh out after tRFH
    tRFHperiod : PROCESS (RFH_in)
    BEGIN
        IF rising_edge(RFH_in) THEN
            RFH_out <= RFH_in after 36 ns;--tdevice_REF166;
        ELSIF falling_edge(RFH_in) THEN
            RFH_out <= RFH_in after 1 ps;
        END IF;
    END PROCESS tRFHperiod;

    SFStateGen : PROCESS (sf_nxt_state)
    begin
        sf_curr_state <= sf_nxt_state;
    END PROCESS SFStateGen;

    -- Exit delaied self-refresh occurence
    RowRfrshDly_proc : PROCESS (RowRefreshing)
    BEGIN
        IF rising_edge(RowRefreshing) THEN
            RowRfrshDly <= '1' after 36 ns;--tdevice_REF166;
        ELSIF falling_edge(RowRefreshing) THEN
            RowRfrshDly <= '0' after 1 ps;
        END IF;
    END PROCESS RowRfrshDly_proc;

    -- Self-refresh state machine
    SelfRefresh: PROCESS (PoweredUp, RFH_in, RFH_out, T_CSNeg, Config_reg_0,
                          cmd, T_RESETNeg, RowRfrshDly)
    BEGIN

        CASE sf_curr_state IS
        WHEN SF_POWER_OFF =>
            IF (PoweredUp = '1') THEN
                sf_nxt_state <= SF_POWER_ON;
            END IF;

        WHEN SF_POWER_ON =>
            IF ((RFH_in = '1') AND falling_edge(T_CSNeg)) THEN
                sf_nxt_state      <= SF_ACC_DLY;

            ELSIF ((RFH_in = '1') AND (T_CSNeg = '0')) THEN
                sf_nxt_state      <= SF_RFRSH_DLY;

            ELSIF ((T_RESETNeg = '0') OR (Config_reg_0(15) = '0')) THEN
                sf_nxt_state      <= SF_RESET;

            ELSE
                sf_nxt_state      <= SF_POWER_ON;
            END IF;

        -- If there was an access atempt during the refresh process then insert
        -- additional delay (RWDS = 1)
        WHEN SF_ACC_DLY =>
            IF (RFH_out = '1') THEN
                sf_nxt_state  <= SF_POWER_ON;
            END IF;

        WHEN SF_RFRSH_DLY =>
            IF rising_edge(T_CSNeg) THEN
                sf_nxt_state  <= SF_RFRSH_DLY_1;
            END IF;

        WHEN SF_RFRSH_DLY_1=>
            IF (RowRfrshDly = '1') THEN
                sf_nxt_state <= SF_POWER_ON;
            END IF;

        WHEN SF_RESET =>
            IF (cmd = wt) THEN
                sf_nxt_state <= SF_POWER_ON;
            END IF;

        END CASE;
    END PROCESS SelfRefresh;

    -- Self-refresh state machine
    SelfRefreshFunctional : PROCESS ( sf_curr_state, T_CSNeg, Config_reg_0,
                                      T_RESETNeg, RFH_in)
    BEGIN

        RowRefreshing <= '0';

        CASE sf_curr_state IS
        WHEN SF_POWER_OFF =>
            RowRefreshing <= '0';

        WHEN SF_POWER_ON =>
            IF ((RFH_in = '1') AND falling_edge(T_CSNeg)) THEN
                RowRefreshing <= RFH_in;

            ELSIF ((RFH_in = '1') AND (T_CSNeg = '0')) THEN
                RowRefreshing <= '0';

            ELSIF ((T_RESETNeg = '0') OR (Config_reg_0(15) = '0')) THEN
                RowRefreshing <= '0';

            ELSE
                RowRefreshing <= RFH_in;

            END IF;

        -- If there was an access atempt during the refresh process then insert
        -- additional delay (RWDS = 1)
        WHEN SF_ACC_DLY =>
            RowRefreshing <= '1';

        WHEN SF_RFRSH_DLY =>
            IF rising_edge(T_CSNeg) THEN
                RowRefreshing <= '1';
            ELSE
                RowRefreshing <= '0';
            END IF;

        WHEN SF_RFRSH_DLY_1=>
            IF (RowRfrshDly = '1') THEN
                RowRefreshing <= '0';
            ELSE
                RowRefreshing <= '1';
            END IF;

        WHEN SF_RESET =>
            RowRefreshing <= '0';

        END CASE;
    END PROCESS SelfRefreshFunctional;

    REFCOLL_ACTIV_PROC : PROCESS (RowRefreshing, T_CSNeg)
    BEGIN
        IF ((RowRefreshing = '1') AND (T_CSNEG = '0')) THEN
            REFCOLL_ACTIV <= '1';
        ELSIF (T_CSNEG = '1') THEN
            REFCOLL_ACTIV <= '0';
        END IF;
    END PROCESS REFCOLL_ACTIV_PROC;

tb  :PROCESS
 --------------------------------------------------------------------------
    --  PROCEDURE to select TC
    -- can be modified to read TC list from file, or to generate random list
    --------------------------------------------------------------------------
    PROCEDURE   Pick_TC
        (Model   :  IN  STRING  := "S27KS0641DPBHI020" )
    IS
    BEGIN
        CASE MODE IS
        WHEN RAND_LATENCY =>
            IF TC_cnt < tc(TS_cnt) THEN
                TC_cnt := TC_cnt+1;
            ELSE
                TC_cnt := 1;
                IF TS_cnt < 4 THEN
                    TS_cnt := TS_cnt+1;
                ELSE
                    IF ErrorInTest='0' THEN
                        REPORT "Test Ended without errors"
                        SEVERITY note;
                    ELSE
                        REPORT "There were errors in test"
                        SEVERITY note;
                    END IF;
                    WAIT;
                END IF;
            END IF;

        WHEN VARIABLE_LATENCY =>
            IF TC_cnt < tc(TS_cnt) THEN
                TC_cnt := TC_cnt+1;
            ELSE
                TC_cnt := 1;
                IF TS_cnt = 1 THEN
                    TS_cnt := 5;
                ELSIF TS_cnt < 7 THEN
                    TS_cnt := TS_cnt+1;
                ELSE
                    IF ErrorInTest='0' THEN
                        REPORT "Test Ended without errors"
                        SEVERITY note;
                    ELSE
                        REPORT "There were errors in test"
                        SEVERITY note;
                    END IF;
                    WAIT;
                END IF;
            END IF;
        END CASE;
    END PROCEDURE Pick_TC;

   ----------------------------------------------------------------------------
    --bus commands, device specific implementation
    ---------------------------------------------------------------------------
    TYPE bus_type IS (bus_idle,
                      bus_standby,  --CS# deasserted,others are don't care
                      bus_enable,   --CS# asserted,others deasserted
                      bus_reset,
                      bus_data_reg,
                      bus_data_mem,
                      bus_latency,
                      bus_ca,
                      bus_read);

    TYPE target_type IS (memdata, reg);
    TYPE config_type IS (config0, config1);
    TYPE brst_type IS (wrap, cont);
    TYPE op_type IS (write, read);

    --bus drive for specific command sequence cycle
    PROCEDURE bus_cycle(
        bus_cmd :IN   bus_type := bus_idle;
        rw      :IN   op_type        :=  write;
        target  :IN   target_type        :=  memdata;
        config  :IN   config_type        :=  config0;
        burst_type :IN   brst_type        :=  wrap;
        data_lo :IN   INTEGER RANGE -1 TO MaxData  := -1; -- -1 for all Z
        data_hi :IN   INTEGER RANGE -1 TO MaxData  := -1; -- -1 for all Z
        address :IN   NATURAL RANGE  0 TO MemSize  :=  0;
        ubm     :IN   NATURAL RANGE  0 TO 1  :=  0; -- Upper Byte Mask
        lbm     :IN   NATURAL RANGE  0 TO 1  :=  0; -- Lower Byte Mask
        tm      :IN   TIME                         := 0 ns)
    IS
        VARIABLE tmpA     : std_logic_vector(21 downto 0);
    BEGIN

        IF data_lo =-1 OR data_hi =-1 THEN -- HiZ
            T_DQ(7 downto 0) <= (OTHERS => 'Z');
            T_RWDS <=  'Z';
        END IF;

        tmpA := to_slv(address, 22);
        CA_bits(34 downto 16) := tmpA(21 downto 3);
        CA_bits(2 downto 0)   := tmpA(2 downto 0);

        IF rw = write THEN
            CA_bits(47) := '0';
        ELSIF rw = read THEN
            CA_bits(47) := '1';
        END IF;

        IF target = memdata THEN
            CA_bits(46) := '0';
        ELSIF target = reg THEN
            CA_bits(46) := '1';
        END IF;

        IF burst_type = wrap THEN
            CA_bits(45) := '0';
        ELSIF burst_type = cont THEN
            CA_bits(45) := '1';
        END IF;
        
        IF config = config1 THEN
            CA_bits(45) := '1';
        END IF;

        IF Config_reg_0(1 DOWNTO 0) = "00" THEN
            BurstLength := 128;
        ELSIF Config_reg_0(1 DOWNTO 0) = "01" THEN
            BurstLength := 64;
        ELSIF Config_reg_0(1 DOWNTO 0) = "10" THEN
            BurstLength := 16;
        ELSIF Config_reg_0(1 DOWNTO 0) = "11" THEN
            BurstLength := 32;
        END IF;

        IF (Config_reg_0(7 downto 4)) = "0000"  THEN
            BurstDelay := 5;
            RefreshDelay := 5;
        ELSIF (Config_reg_0(7 downto 4)) = "0001"  THEN
            BurstDelay := 6;
            RefreshDelay := 6;
        ELSIF (Config_reg_0(7 downto 4)) = "1111"  THEN
            BurstDelay := 4;
            RefreshDelay := 4;
        ELSIF (Config_reg_0(7 downto 4)) = "1110"  THEN
            BurstDelay := 3;
            RefreshDelay := 3;
        END IF;

        CASE bus_cmd IS

            WHEN bus_idle =>
                ClockEnable:= TRUE;
                T_RESETNeg <= '1';
                T_CSNeg    <= '1';
                WAIT FOR 30 ns;

            WHEN bus_standby =>
                T_CSNeg    <= '1';
                WAIT FOR 30 ns;

            WHEN bus_enable =>
                T_CSNeg    <= '0';
                CA_bits := (OTHERS => '0');

                WAIT FOR tm ;

            WHEN bus_reset =>
                T_RESETNeg <= '0', '1' AFTER tm ;
                WAIT FOR 30 ns;

            WHEN bus_latency =>

                IF Config_reg_0(3)='1' THEN -- fixed latency
                    FOR I IN RefreshDelay-2 DOWNTO 0 LOOP
                        WAIT UNTIL falling_edge(T_CK);
                    END LOOP;
                    FOR I IN BurstDelay-1 DOWNTO 0 LOOP
                        WAIT UNTIL falling_edge(T_CK);
                    END LOOP;
                ELSIF Config_reg_0(3)='0' THEN -- variable latency
                    IF (REFCOLL_ACTIV = '1') THEN
                        FOR I IN RefreshDelay-2 DOWNTO 0 LOOP
                            WAIT UNTIL falling_edge(T_CK);
                        END LOOP;
                        FOR I IN BurstDelay-1 DOWNTO 0 LOOP
                            WAIT UNTIL falling_edge(T_CK);
                        END LOOP;
                    ELSE
                        FOR I IN BurstDelay-2 DOWNTO 0 LOOP
                            WAIT UNTIL falling_edge(T_CK);
                        END LOOP;
                    END IF;
                END IF;
                WAIT FOR half_period/2;

            WHEN bus_data_reg =>
                T_DQ <= to_slv(data_hi,8);
                WAIT UNTIL rising_edge(T_CK);
                WAIT FOR half_period/2;
                T_DQ <= to_slv(data_lo,8);
                WAIT UNTIL falling_edge(T_CK);
                WAIT FOR half_period/2;

                T_DQ(7 downto 0) <= (OTHERS => 'Z');

            WHEN bus_data_mem =>
                T_RWDS <= to_sl(ubm);
                T_DQ <= to_slv(data_hi,8);
                WAIT UNTIL rising_edge(T_CK);
                WAIT FOR half_period/2;
                T_RWDS <= to_sl(lbm);
                T_DQ <= to_slv(data_lo,8);
                WAIT UNTIL falling_edge(T_CK);
                WAIT FOR half_period/2;

            WHEN bus_ca =>
                FOR I IN 6 DOWNTO 1 LOOP
                    T_DQ <= CA_bits(8*i-1 DOWNTO 8*i-8);
                    WAIT UNTIL T_CK'EVENT;
                    WAIT FOR half_period/2;
                END LOOP;

            WHEN bus_read =>
                T_DQ(7 downto 0)      <= (OTHERS => 'Z');

                IF Config_reg_0(3)='1' THEN -- fixed latency
                    FOR I IN RefreshDelay-2 DOWNTO 0 LOOP
                        WAIT UNTIL falling_edge(T_CK);
                    END LOOP;
                    FOR I IN BurstDelay-1 DOWNTO 0 LOOP
                        WAIT UNTIL falling_edge(T_CK);
                    END LOOP;
                ELSIF Config_reg_0(3)='0' THEN -- variable latency
                    IF (REFCOLL_ACTIV = '1') THEN
                        FOR I IN RefreshDelay-2 DOWNTO 0 LOOP
                            WAIT UNTIL falling_edge(T_CK);
                        END LOOP;
                        FOR I IN BurstDelay-1 DOWNTO 0 LOOP
                            WAIT UNTIL falling_edge(T_CK);
                        END LOOP;
                    ELSE
                        FOR I IN BurstDelay-2 DOWNTO 0 LOOP
                            WAIT UNTIL falling_edge(T_CK);
                        END LOOP;
                    END IF;
                END IF;

                FOR I IN data_num-1 downto 0 LOOP
                    WAIT UNTIL falling_edge(T_CK);
                END LOOP;
                WAIT UNTIL falling_edge(T_CK);
                ClockEnable:= FALSE; --Clock Generator is disabled

                WAIT FOR 10 ns;
        END CASE;
    END PROCEDURE;

    ----------------------------------------------------------------------------
    --procedure to decode commands into specific bus command sequence
    ---------------------------------------------------------------------------
    PROCEDURE cmd_dc
        (   command  :   IN  cmd_rec   )
    IS
        VARIABLE    D_lo    : INTEGER RANGE  -1 to MaxData;
        VARIABLE    D_hi    : INTEGER RANGE  -1 to MaxData;
        VARIABLE    Addr    : NATURAL RANGE 0 to MemSize  :=0;
        VARIABLE    lbm, ubm : NATURAL RANGE  0 to 1;
        VARIABLE    i        : NATURAL;
    BEGIN
        CASE command.cmd IS

            WHEN    idle        =>
                bus_cycle(bus_cmd => bus_idle);

            WHEN h_reset =>
                Config_reg_0(15 downto 0)  <= "1000111100011111";
                Config_reg_1(15 downto 0)  <= "0000000000000010";
                bus_cycle(bus_cmd => bus_reset,
                          tm      => command.wtime);

            WHEN wr_mem_cont =>
                Addr :=  command.addr;
                D_lo :=  command.data_lo;
                D_hi :=  command.data_hi;
                lbm  :=  command.lbm;
                ubm  :=  command.ubm;

                bus_cycle(bus_cmd => bus_enable);

                bus_cycle(bus_cmd => bus_ca,
                          rw      => write,
                          target  => memdata,
                          burst_type => cont,
                          address => Addr,
                          tm      => command.wtime);

                WR_LEGACY_WRAP := FALSE;
                WR_ADDR_WRAP   := FALSE;
                WR_CONTINUOUS  := FALSE;

                WrAddress := 2*Addr;
                WrAddress_Start := 2*Addr;

                bus_cycle(bus_cmd => bus_latency);

            WHEN wr_mem_wrap =>
                Addr :=  command.addr;
                D_lo :=  command.data_lo;
                D_hi :=  command.data_hi;
                lbm  :=  command.lbm;
                ubm  :=  command.ubm;

                bus_cycle(bus_cmd => bus_enable);

                bus_cycle(bus_cmd => bus_ca,
                          rw      => write,
                          target  => memdata,
                          burst_type => wrap,
                          address => Addr,
                          tm      => command.wtime);

                WR_LEGACY_WRAP := FALSE;
                WR_ADDR_WRAP   := FALSE;
                WR_CONTINUOUS  := FALSE;

                WrAddress := 2*Addr;
                WrAddress_Start := 2*Addr;

                bus_cycle(bus_cmd => bus_latency);

            WHEN w_data_cont | w_data_wrap =>
                D_lo :=  command.data_lo;
                D_hi :=  command.data_hi;
                lbm  :=  command.lbm;
                ubm  :=  command.ubm;

                IF command.cmd =  w_data_cont THEN
                    bus_cycle(bus_cmd => bus_data_mem,
                            data_lo  => D_lo,
                            data_hi  => D_hi,
                            lbm      => lbm,
                            ubm      => ubm,
                            burst_type => cont);
                ELSIF command.cmd =  w_data_wrap THEN
                    bus_cycle(bus_cmd => bus_data_mem,
                            data_lo  => D_lo,
                            data_hi  => D_hi,
                            lbm      => lbm,
                            ubm      => ubm,
                            burst_type => wrap);
                END IF;

                IF lbm = 0 AND command.aux = valid THEN
                    Mem(WrAddress) := command.data_lo;
                END IF;
                IF ubm = 0 AND command.aux = valid THEN
                    Mem(WrAddress+1) := D_hi;
                END IF;

                IF CA_bits(45) = '1' OR WR_CONTINUOUS THEN -- continuous burst
                    IF WrAddress = MemSize - 1 THEN
                        WrAddress := 0;
                    ELSE
                        WrAddress := WrAddress + 2;
                    END IF;

                ELSIF CA_bits(45) = '0' THEN -- wrapped burst
                    IF Config_reg_0(2) = '1' THEN -- legacy wrapped manner
                        IF BurstLength=16 OR BurstLength=32 OR
                        BurstLength=64 OR BurstLength=128 THEN
                            WrAddress := WrAddress + 2;
                            IF WrAddress mod (BurstLength/2) = 0 THEN
                                WrAddress := WrAddress - BurstLength/2;
                            END IF;
                        END IF;

                    ELSIF Config_reg_0(2) = '0' THEN -- hybrid burst
                        IF BurstLength=16 OR BurstLength=32 OR
                        BurstLength=64 OR BurstLength=128 THEN
                            WrAddress := WrAddress + 2;
                            WrAddress_slv := to_slv(WrAddress, HiAddrBit+1);
                            IF WrAddress mod (BurstLength/2) = 0 THEN
                                WrAddress := WrAddress - BurstLength/2;
                            END IF;
                            IF WrAddress =WrAddress_Start THEN
                                WrAddress :=(WrAddress_Start/(BurstLength/2))*BurstLength/2
                                                                + BurstLength/2;
                                IF WrAddress = MemSize + 1 THEN
                                    WrAddress := 0;
                                END IF;
                                WR_CONTINUOUS := TRUE;
                            END IF;
                        END IF;
                    END IF;
                END IF;

            WHEN wr_reg =>
                Addr :=  command.addr;
                D_lo :=  command.data_lo;
                D_hi :=  command.data_hi;

                bus_cycle(bus_cmd => bus_enable);

                bus_cycle(bus_cmd => bus_ca,
                          rw      => write,
                          target  => reg,
                          config  => config0,
                          address => Addr,
                          tm      => command.wtime);

                bus_cycle(bus_cmd => bus_data_reg,
                         data_lo  => D_lo,
                         data_hi  => D_hi);
                IF CA_bits(0) = '0' THEN
                Config_reg_0(7 downto 0) <= to_slv(D_lo, 8);
                Config_reg_0(15 downto 8) <= to_slv(D_hi, 8);
                ELSE
                Config_reg_1(7 downto 0) <= to_slv(D_lo, 8);
                Config_reg_1(15 downto 8) <= to_slv(D_hi, 8);
                END IF;

                bus_cycle(bus_cmd => bus_standby);

                IF CA_bits(0) = '0' THEN
                Config_reg_0(7 downto 0) <= to_slv(D_lo, 8);
                Config_reg_0(15 downto 8) <= to_slv(D_hi, 8);
                ELSE
                Config_reg_1(7 downto 0) <= to_slv(D_lo, 8);
                Config_reg_1(15 downto 8) <= to_slv(D_hi, 8);
                END IF;
                
            WHEN wr_reg1 =>
                Addr :=  command.addr;
                D_lo :=  command.data_lo;
                D_hi :=  command.data_hi;

                bus_cycle(bus_cmd => bus_enable);

                bus_cycle(bus_cmd => bus_ca,
                          rw      => write,
                          target  => reg,
                          config  => config1,
                          address => Addr,
                          tm      => command.wtime);

                bus_cycle(bus_cmd => bus_data_reg,
                         data_lo  => D_lo,
                         data_hi  => D_hi);
                IF CA_bits(0) = '0' THEN
                Config_reg_0(7 downto 0) <= to_slv(D_lo, 8);
                Config_reg_0(15 downto 8) <= to_slv(D_hi, 8);
                ELSE
                Config_reg_1(7 downto 0) <= to_slv(D_lo, 8);
                Config_reg_1(15 downto 8) <= to_slv(D_hi, 8);
                END IF;

                bus_cycle(bus_cmd => bus_standby);

                IF CA_bits(0) = '0' THEN
                Config_reg_0(7 downto 0) <= to_slv(D_lo, 8);
                Config_reg_0(15 downto 8) <= to_slv(D_hi, 8);
                ELSE
                Config_reg_1(7 downto 0) <= to_slv(D_lo, 8);
                Config_reg_1(15 downto 8) <= to_slv(D_hi, 8);
                END IF;

            WHEN  rd_mem_wrap | rd_mem_cont | rd_reg |
                  rd_reg_1 | rd_reg_id_0 | rd_reg_id_1 | rd_HiZ =>
                IF command.cmd = rd_mem_cont OR
                command.cmd = rd_mem_wrap THEN
                    Addr :=  2*command.addr;
                ELSE
                    Addr :=  command.addr;
                END IF;

                bus_cycle(bus_cmd => bus_enable);

                IF command.cmd = rd_mem_wrap THEN
                    bus_cycle(bus_cmd => bus_ca,
                            rw => read,
                            target  => memdata,
                            burst_type => wrap,
                            address => Addr);
                ELSIF command.cmd = rd_mem_cont OR
                      command.cmd = rd_HiZ THEN
                    bus_cycle(bus_cmd => bus_ca,
                            rw => read,
                            target  => memdata,
                            burst_type => cont,
                            address => Addr);
                ELSIF command.cmd = rd_reg OR
                      command.cmd = rd_reg_1 OR
                      command.cmd = rd_reg_id_0 OR
                      command.cmd = rd_reg_id_1 THEN
                    bus_cycle(bus_cmd => bus_ca,
                            rw => read,
                            target  => reg,
                            burst_type => cont,
                            address => Addr);
                END IF;

                bus_cycle(bus_cmd => bus_read);

                bus_cycle(bus_cmd => bus_standby);

            WHEN clock =>
                IF command.wtime /= 0 ns THEN
                    change_ck <= '1';
                    half_period_tmp <= command.wtime/2;
                ELSE
                    change_ck <= '0';
                END IF;

            WHEN    wt          =>
                WAIT FOR command.wtime;

            WHEN    OTHERS    => NULL;
            WAIT FOR command.wtime;
        END CASE;
    END PROCEDURE cmd_dc;

    VARIABLE cmd_cnt    :   NATURAL;
    VARIABLE command    :   cmd_rec;

BEGIN
    TestInit(TimingModel);
    Pick_TC (Model   =>  TimingModel);

    Tseries <=  ts_cnt  ;
    Tcase   <=  tc_cnt  ;

    Generate_TC
        (Model       => TimingModel,
         Series      => ts_cnt,
         TestCase    => tc_cnt,
         command_seq => cmd_seq);

    cmd_cnt := 1;

    WHILE cmd_seq(cmd_cnt).cmd /= done LOOP
        command  := cmd_seq(cmd_cnt);
        cmd      <=  command.cmd;
        data_num <= command.data_num;
        cmd_dc(command);
        cmd_cnt :=cmd_cnt + 1;
    END LOOP;

END PROCESS tb;

-------------------------------------------------------------------------------
-- Checker process,
-------------------------------------------------------------------------------
checker: PROCESS

    VARIABLE Data_reg    : std_logic_vector(15 downto 0);
    VARIABLE RdAddress       :   NATURAL;
    VARIABLE RdAddress_Start :   NATURAL;

    VARIABLE RD_ADDR_WRAP    : BOOLEAN := FALSE;
    VARIABLE RD_LEGACY_WRAP  : BOOLEAN := FALSE;
    VARIABLE RD_CONTINUOUS   : BOOLEAN := FALSE;
    VARIABLE RdAddress_slv   : std_logic_vector(HiAddrBit downto 0);

BEGIN

    IF (T_CSNeg='0') THEN
        RD_ADDR_WRAP    := FALSE;
        RD_LEGACY_WRAP  := FALSE;
        RD_CONTINUOUS   := FALSE;

        IF (cmd = rd_mem_cont) OR (cmd = rd_mem_wrap) OR (cmd = rd_reg) OR
        (cmd = rd_reg_1) OR (cmd = rd_reg_id_0) OR (cmd = rd_reg_id_1) THEN
            FOR I IN 3 DOWNTO 0 LOOP
                WAIT UNTIL T_CK'EVENT;
            END LOOP;

            RdAddress := 2 * to_nat(CA_bits(34 downto 16) & CA_bits(2 downto 0));
            RdAddress_Start := RdAddress;
            RdAddress_slv := to_slv(RdAddress, 22);
                --Latency Clocks
            IF Config_reg_0(3)='1' THEN -- fixed latency
                FOR I IN RefreshDelay-1 DOWNTO 0 LOOP
                    WAIT UNTIL falling_edge(T_CK);
                END LOOP;
                FOR I IN BurstDelay-1 DOWNTO 0 LOOP
                    WAIT UNTIL falling_edge(T_CK);
                END LOOP;
            ELSIF Config_reg_0(3)='0' THEN -- variable latency
                IF REFCOLL_ACTIV = '1' THEN
                    FOR I IN RefreshDelay-1 DOWNTO 0 LOOP
                        WAIT UNTIL falling_edge(T_CK);
                    END LOOP;
                    FOR I IN BurstDelay-1 DOWNTO 0 LOOP
                        WAIT UNTIL falling_edge(T_CK);
                    END LOOP;
                ELSE
                    FOR I IN BurstDelay-1 DOWNTO 0 LOOP
                        WAIT UNTIL falling_edge(T_CK);
                    END LOOP;
                END IF;
            END IF;

            FOR I IN data_num-1 DOWNTO 0 LOOP
                Data_reg(15 downto 0) := (OTHERS => '0');
                IF I=data_num-1 THEN
                    WAIT UNTIL rising_edge(t_CK);
                    WAIT FOR 6.15 ns;
                ELSE
                    WAIT FOR half_period;
                END IF;
                Data_reg(15 DOWNTO 8) := T_DQ;

                IF cmd /= rd_HiZ THEN
                    Check_RWDS(
                        RWDS       => T_RWDS,
                        RWDSValue  => '1',
                        check_err => check_err);
                END IF;

                WAIT FOR half_period;
                Data_reg(7 DOWNTO 0) := T_DQ;

                IF cmd /= rd_HiZ THEN
                    Check_RWDS(
                        RWDS       => T_RWDS,
                        RWDSValue  => '0',
                        check_err => check_err);
                END IF;

                IF cmd = rd_mem_cont OR RD_CONTINUOUS THEN
                    Check_read (
                        DQ       => Data_reg,
                        Data1     => Mem(RdAddress),
                        Data2     => Mem(RdAddress+1),
                        check_err=> check_err);

                    -- if the highest address is reached
                    IF RdAddress = MemSize - 1 THEN
                        RdAddress := 0;
                    ELSE
                        RdAddress := RdAddress + 2;
                    END IF;

                ELSIF cmd = rd_mem_wrap THEN
                    Check_read (
                        DQ       => Data_reg,
                        Data1     => Mem(RdAddress),
                        Data2     => Mem(RdAddress+1),
                        check_err=> check_err);

                    IF Config_reg_0(2) = '1' THEN -- legacy wrapped manner
                        IF BurstLength=16 OR BurstLength=32 OR
                        BurstLength=64 OR BurstLength=128 THEN
                            RdAddress := RdAddress + 2;
                            IF RdAddress mod (BurstLength/2) = 0 THEN
                                RdAddress := RdAddress - BurstLength/2;
                            END IF;
                        END IF;

                    ELSIF Config_reg_0(2) = '0' THEN -- hybrid burst
                        IF BurstLength=16 OR BurstLength=32 OR
                        BurstLength=64 OR BurstLength=128 THEN
                            RdAddress := RdAddress + 2;
                            IF RdAddress mod (BurstLength/2) = 0 THEN
                                RdAddress := RdAddress - BurstLength/2;
                            END IF;
                            IF RdAddress =RdAddress_Start THEN
                                RdAddress :=(RdAddress_Start/(BurstLength/2))*BurstLength/2
                                                                + BurstLength/2;
                                IF RdAddress = MemSize + 1 THEN
                                    RdAddress := 0;
                                END IF;
                                RD_CONTINUOUS := TRUE;
                            END IF;
                        END IF;
                    END IF;

                ELSIF cmd = rd_HiZ THEN
                    Check_Z (
                        DQ       => T_DQ,
                        check_err=> check_err);

                ELSIF cmd = rd_reg THEN
                    Check_read (
                        DQ       => Data_reg,
                        Data1     => to_nat(Config_reg_0(7 DOWNTO 0)),
                        Data2     => to_nat(Config_reg_0(15 DOWNTO 8)),
                        check_err=>check_err);

                ELSIF cmd = rd_reg_1 THEN
                    Check_read (
                        DQ        => Data_reg,
                        Data1     => to_nat(Config_reg_1(7 DOWNTO 0)),
                        Data2     => to_nat(Config_reg_1(15 DOWNTO 8)),
                        check_err => check_err);

                ELSIF cmd = rd_reg_id_0 THEN
                    Check_read (
                        DQ        => Data_reg,
                        Data1     => to_nat(ID_Register_0(7 DOWNTO 0)),
                        Data2     => to_nat(ID_Register_0(15 DOWNTO 8)),
                        check_err => check_err);

                ELSIF cmd = rd_reg_id_1 THEN
                    Check_read (
                        DQ        => Data_reg,
                        Data1     => to_nat(ID_Register_1(7 DOWNTO 0)),
                        Data2     => to_nat(ID_Register_1(15 DOWNTO 8)),
                        check_err => check_err);
                END IF;

            END LOOP;
        END IF;
    END IF;
    WAIT ON T_CSNeg;

END PROCESS checker;

default:    PROCESS
        -- text file input variables
        FILE mem_f             : text  is  mem_file;
        VARIABLE buf           : line;
        VARIABLE addr_ind      : NATURAL;
        VARIABLE ind           : NATURAL := 0;
        VARIABLE data_slv      : std_logic_vector(15 downto 0);
BEGIN

    --Preload Control
    -----------------------------------------------------------------------
    -- File Read Section
    -----------------------------------------------------------------------
    IF UserPreload THEN
    ----------------------------------------------------------------------------
    -----s27ks0641 memory preload file format ---------------------------------
    ----------------------------------------------------------------------------
    --   /         - comment
    --   @aaaaaaaa - <aaaaaaaa> stands for address within sector
    --   dddd      - <dddd> is word to be written at Mem(*)(aaaaaaaa++)
    --             (aaaaaaaa is incremented at every load)
    --   only first 1-9 columns are loaded. NO empty lines !!!!!!!!!!!!!!!!
    ----------------------------------------------------------------------------
        IF (mem_file /= "none") THEN
            addr_ind := 0;
            Mem := (OTHERS => MaxData);
            WHILE (not ENDFILE (mem_f)) LOOP
                READLINE (mem_f, buf);
                IF buf(1) = '/' THEN --comment
                    NEXT;
                ELSIF buf(1) = '@' THEN --address
                    addr_ind := h(buf(2 to 7));
                ELSE
                    IF addr_ind <= (MemSize + 1)/2 THEN
                        data_slv := to_slv(h(buf(1 to 4)), 16);
                        Mem(2*addr_ind) := to_nat(data_slv(7 DOWNTO 0));
                        Mem(2*addr_ind+1) := to_nat(data_slv(15 DOWNTO 8));
                        addr_ind := addr_ind + 1;
                    END IF;
                END IF;
            END LOOP;
        END IF;
    END IF;

    WAIT;

END PROCESS default;

END vhdl_behavioral_static_memory_allocation;