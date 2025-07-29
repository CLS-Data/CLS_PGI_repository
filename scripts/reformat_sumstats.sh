#!/bin/bash

input_file="$1"
output_file="$2"

# Check if input and output files are provided
if [ -z "$input_file" ]; then
    echo "Error: Input file not specified." >&2
    exit 1
fi

if [ -z "$output_file" ]; then
    echo "Error: Output file not specified." >&2
    exit 1
fi

# Create a temporary file to store the AWK script
awk_script=$(mktemp)
if [ -z "$awk_script" ]; then
    echo "Error: Could not create temporary file." >&2
    exit 1
fi

# Write the AWK script into the temporary file
cat << 'EOF' > "$awk_script"
BEGIN {
    OFS = "\t"
    header_found = 0
}

# Function to trim whitespace
function trim(str) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", str)
    return str
}

# Identify relevant summary statistic columns and output to standardised header
{
    if (!header_found) {
        split($0, header_cols, "[ \t]+")
        num_cols = length(header_cols)

        # Identify column indices by matching header names
        for (i = 1; i <= num_cols; i++) {
            col = tolower(header_cols[i])
            gsub(/[^a-z0-9_]/, "", col)
            col = trim(col)

            if (col ~ /^(rsid|rs_id|variant_id|snp|marker_name|markername|id)$/) {
                col_SNP = i
            } else if (col ~ /^(chromosome|chr|chromosome_number|chr_number|chrom|#chrom|chr_name|chromsome|chromosome(b37))$/) {
                col_CHR = i
            } else if (col ~ /^(base_pair_location|bp|position|base_pair_pos|pos|bpos|chr_position|position(b37))$/) {
                col_BP = i
            } else if (col ~ /^(effect_allele|a1|ref|effect_allele_name|allele1|ea|tested_allele|ref_allele|effectallele)$/) {
                col_A1 = i
            } else if (col ~ /^(other_allele|a2|alt|other_allele_name|allele2|nea|oa|a0|non_effect_allele|allele0|alt_allele|noneffectallele)$/) {
                col_A2 = i
            } else if (col ~ /^(odds_ratio|or|odds|odds_ratio_value)$/) {
                col_OR = i
            } else if (col ~ /^(beta|effect_size|beta_coefficient|effect_size_value|effect|stdbeta|effect_weight|beta1|fixedeffects_beta|logor)$/) {
                col_BETA = i
            } else if (col ~ /^(p_value|p|pval|pvalue|p_bolt_lmm|fixedeffects_pvalue)$/) {
                col_P = i
            }
        }

        print "SNP", "CHR", "BP", "A1", "A2", "BETA", "P"
        header_found = 1

    } else {
        snp = (col_SNP ? $col_SNP : ".")

        # Indeintifying SNP ID if it is not in the expected column
        if (snp !~ /^rs[0-9]+$/) {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^rs[0-9]+$/) {
                    snp = $i
                    break
                }
            }
        }

        chr = (col_CHR ? $col_CHR : ".")
        sub(/^chr/, "", chr)

        bp = (col_BP ? $col_BP : ".")

        # If SNP is in chr:bp format, split it to extract CHR and BP
        if (index(snp, ":") > 0) {
            split(snp, parts, ":")
            chr = parts[1]
            bp = parts[2]
            sub(/_.*$/, "", bp)
            sub(/^chr/, "", chr)
        }

        a1 = (col_A1 ? toupper($col_A1) : ".")
        a2 = (col_A2 ? toupper($col_A2) : ".")

        # Get beta, or if only OR available, use log(OR)
        if (col_BETA && $col_BETA != "") {
            effect = $col_BETA
        } else if (col_OR && $col_OR != "" && $col_OR > 0) {
            effect = log($col_OR)
        } else {
            effect = "."
        }

        p = (col_P ? $col_P : ".")   # Get p-value

        # Output standardized row
        print snp, chr, bp, a1, a2, effect, p
    }
}
EOF

# Function to identify if a file is gzipped
is_gzipped() {
    if gzip -t "$1" >/dev/null 2>&1; then
        return 0   # True
    else
        return 1   # False
    fi
}

# Choose appropriate command to read input file (cat or zcat)
if is_gzipped "$input_file"; then
    input_command="zcat"
else
    input_command="cat"
fi

# Run the input file through the AWK script and write to output
$input_command "$input_file" | awk -f "$awk_script" > "$output_file"
if [ $? -ne 0 ]; then
    echo "Error: AWK processing failed." >&2
    rm "$awk_script"
    exit 1
fi

# Clean up: remove temporary AWK script
rm "$awk_script"
