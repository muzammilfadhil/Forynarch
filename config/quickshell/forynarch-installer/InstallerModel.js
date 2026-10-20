.pragma library

var steps = ["Welcome", "Connection", "Location", "Keyboard", "Storage", "Account", "Drivers", "Software", "Review"];
var methods = [
    {id:"install-erase",label:"Use an entire disk",detail:"Install Forynarch as the only operating system on the selected disk. All data on that disk would be erased."},
    {id:"install-alongside",label:"Install alongside another operating system",detail:"Prepare a Linux root partition, then choose it and an existing EFI partition. Other operating systems and partitions are preserved."},
    {id:"install-manual",label:"Use prepared partitions",detail:"Choose the root partition to format as ext4 and the FAT32 EFI partition to keep. Open Partition Manager to prepare or inspect the layout."}
];
var keyboards = [
    {id:"us",label:"English (US)"},{id:"gb",label:"English (UK)"},
    {id:"de",label:"German"},{id:"fr",label:"French"},
    {id:"es",label:"Spanish"},{id:"br",label:"Portuguese (Brazil)"},
    {id:"jp",label:"Japanese"},{id:"id",label:"Indonesian"}
];
function accountError(name, username, hostname, password, confirmation, passwordless) {
    if (!name.trim() || name.length > 100) return "Enter your name (up to 100 characters).";
    if (/[\u0000\r\n:]/.test(name)) return "Your name cannot contain colons, line breaks or null characters.";
    if (!/^[a-z_][a-z0-9_-]{0,30}$/.test(username) || ["root","liveuser","nobody","builder"].indexOf(username)>=0)
        return "Choose a lowercase username, starting with a letter; root and system accounts are reserved.";
    if (!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(hostname)) return "Use a computer name of 1–63 lowercase letters, numbers or hyphens.";
    if (passwordless === true) return "";
    if (password.length < 8) return "Use a password of at least 8 characters.";
    if (password.length > 1024) return "Use a password of no more than 1024 characters.";
    if (password.indexOf("\n")>=0 || password.indexOf("\r")>=0 || password.indexOf("\u0000")>=0) return "The password cannot contain line breaks or null characters.";
    if (password !== confirmation) return "The passwords do not match.";
    return "";
}
function toggle(values, id, enabled) {
    var next=values.filter(function(v){return v!==id;});
    if(enabled)next.push(id);
    return next;
}
function storageError(info, disk, method, root, efi) {
    if (!info.live) return "Start installation from the Forynarch Live USB.";
    if (!info.uefi) return "Restart the Live USB in UEFI mode. GPT describes the disk; UEFI describes how this session was booted.";
    if (info.secureBootEnabled) return "This installer does not support Secure Boot. Check your firmware boot settings before installing.";
    if (!disk) return "Select the disk where Forynarch will be installed.";
    if (disk.containsSystem) return "This disk contains the running system, Live USB or active swap. Select another disk.";
    if (disk.readOnly) return "The selected disk is read-only.";
    if ((disk.partitions || []).some(function(partition) { return partition.mounted; })) return "Unmount volumes on this disk in File Manager or Partition Manager before installation.";
    if (!disk.stableIdentity) return "A unique disk identity is unavailable. Refresh disks and check the device connection.";
    if (!method) return "Choose an installation method.";
    if (method === "install-erase") return disk.size < 34359738368 ? "Choose a disk of at least 32 GiB." : "";
    if (disk.table !== "gpt") return "This disk was not detected as GPT. Apply any pending changes in Partition Manager, then refresh disks.";
    if (!disk.geometryKnown) return "Partition boundaries could not be verified. Inspect the partition table in Partition Manager, then refresh disks.";
    if (!root || !efi) return "Choose a Linux root partition and an EFI System Partition. Use Partition Manager to prepare them if needed.";
    return "";
}
// Explicit allowlist: passwords never enter a Process argument, IPC response or log.
function publicPlan(state) {
    return {kind:state.method,revision:state.revision,diskId:state.diskId,
        offline:state.offline,selectedGroups:state.selectedGroups.slice(),filesystem:state.filesystem,
        sizeGiB:32,locale:"en_US.UTF-8",timezone:state.timezone,keyboard:state.keyboard,
        fullName:state.fullName,username:state.username,hostname:state.hostname,
        selectedDrivers:state.selectedDrivers.slice(),passwordless:state.passwordless===true,
        rootPartitionId:state.rootPartitionId||"",efiPartitionId:state.efiPartitionId||"",registerBootEntry:state.registerBootEntry===true,reviewOnly:true};
}
