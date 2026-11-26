-- Terraform - Infrastructure-as-code tool (binary: `terraform`).
--
-- Verified 2026-11-26 against HashiCorp official release 1.17.2: every SHA256
-- below was verified against `terraform_1.17.2_SHA256SUMS` and downloaded
-- archives. All six archives are flat `.zip` files (no enclosing directory)
-- packing `terraform[.exe]` and `LICENSE.txt`. The Linux binaries (x86_64 and
-- aarch64) are statically linked Go executables (`readelf -d`: no NEEDED); the
-- Windows x86_64 PE32+ binary imports only `kernel32.dll`.
package = {
    spec = "2",

    name = "terraform",
    description = "Infrastructure-as-code tool for building, changing, and versioning cloud and on-prem resources safely and efficiently",
    homepage = "https://www.terraform.io",
    authors = {"HashiCorp"},
    maintainers = {"https://github.com/hashicorp/terraform/graphs/contributors"},
    licenses = {"BSL-1.1"},
    repo = "https://github.com/hashicorp/terraform",
    docs = "https://developer.hashicorp.com/terraform/docs",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"devops", "iac", "cloud", "cli", "tools"},
    keywords = {"terraform", "iac", "infrastructure", "devops", "hashicorp"},

    programs = {"terraform"},
    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "1.17.2" },
            ["1.17.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e6f16b2f0b137ee5729caa8c4e79a3bae4ee261acd198a1fcfa8584a6296605b",
                    aarch64 = "858e08c181a76b6b223e8c767a8e983922eebe2d062db949a2de66ce040c368c",
                },
            },
        },
        macosx = {
            source = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_darwin_${arch_alias}.zip",
            ["latest"] = { ref = "1.17.2" },
            ["1.17.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "66b472dcc36cf770d83757ed4d002c476174842c05c68637b40a7e99519cf3e1",
                    aarch64 = "da0c7ef278a911347862758e7573a5907365e66485c2637cf5c217c5e227992e",
                },
            },
        },
        windows = {
            source = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.17.2" },
            ["1.17.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "2244b7a379ea8c4b224a2eab411b7288f41ef36316fca27ae4b51b1cf2a53024",
                    aarch64 = "4b614fe5aacfe76f6b167c9caad19358a505a601ade0ed25c664fb8ab6f1df19",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "terraform", "LICENSE.txt" })
        or payload.present({ "terraform.exe", "LICENSE.txt" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("terraform: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."

    os.tryrm(dir)

    if os.isfile(archive) then
        fs.mkdir_p(dir)
        system.exec(string.format('unzip -oq "%s" -d "%s"', normalized, dir))
    elseif os.isfile(parent .. "/terraform") then
        fs.mkdir_p(dir)
        for _, f in ipairs({ "terraform", "LICENSE.txt" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
    else
        payload.unpack{}
    end

    if os.isfile(dir .. "/terraform") then
        system.exec(string.format('chmod +x "%s"', dir .. "/terraform"))
    end

    local exe = os.isfile(dir .. "/terraform.exe") and "terraform.exe" or "terraform"
    payload.require({ exe, "LICENSE.txt" })
    return true
end

function config()
    xvm.add("terraform", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("terraform")
    return true
end
