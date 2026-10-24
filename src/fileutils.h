#pragma once

#include <chrono>
#include <filesystem>
#include <string>

std::string lookup_file(const std::string &filename, 
                        const std::string &path, const std::string &fallbackpath);

// Last modification time of a file as whole seconds since the filesystem clock epoch.
// Only meant for change detection / cache keys (the epoch is implementation-defined).
inline long long fs_last_write_time(const std::filesystem::path &p)
{
	return std::chrono::duration_cast<std::chrono::seconds>(std::filesystem::last_write_time(p).time_since_epoch()).count();
}
