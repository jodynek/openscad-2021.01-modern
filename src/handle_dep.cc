#include "handle_dep.h"
#include "printutils.h"
#include <string>
#include <sstream>
#include <stdlib.h> // for system()
#include <unordered_set>
#include <boost/algorithm/string/replace.hpp>
#include <filesystem>
namespace fs = std::filesystem;

std::unordered_set<std::string> dependencies;
const char *make_command = nullptr;

void handle_dep(const std::string &filename)
{
	fs::path filepath(filename);
	std::string dep = filepath.generic_string();
	boost::algorithm::replace_all(dep, " ", "\\ "); // escape spaces for make
	if (dependencies.find(dep) != dependencies.end()) {
		return; // included and used files are very likely to be added many times by the parser
	}
	dependencies.insert(dep);

	if (make_command && !fs::exists(filepath)) {
		system(STR(make_command << " '" << boost::algorithm::replace_all_copy(filename, "'", "'\\''") << "'").c_str()); // FIXME: Handle error
	}
}

bool write_deps(const std::string &filename, const std::string &output_file)
{
	FILE *fp = fopen(filename.c_str(), "wt");
	if (!fp) {
		fprintf(stderr, "Can't open dependencies file `%s' for writing!\n", filename.c_str());
		return false;
	}
	fprintf(fp, "%s:", output_file.c_str());

	for(const auto &str : dependencies) {
		fprintf(fp, " \\\n\t%s", str.c_str());
	}
	fprintf(fp, "\n");
	fclose(fp);
	return true;
}
