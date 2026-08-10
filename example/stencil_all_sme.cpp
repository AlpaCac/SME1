#include <arm_sme.h>
#include <arm_sve.h>
#include <chrono>
#include <iostream>
#include <cstdlib>
#include <cstring>

__arm_new("za")
void stencil1D_3point_sme(double* __restrict__ grid, double* __restrict__ new_grid, int size, int stride )
__arm_streaming {
    uint64_t SVL = svcntd();
    svfloat64_t weight_vec = svdup_f64(1.0 / 3.0);
    svbool_t pg_all = svptrue_b64();
    
    for(int i=1; i<size-1; i+=stride) {
        for(int j=0; j<SVL*stride; j+=SVL) {
            int idx = i+j;
            if(idx>=size-1) break;
            svbool_t pg = svwhilelt_b64(idx, size-1);
            if( !svptest_any(svptrue_b64(), pg)) break;
            
            svfloat64_t center = svld1_f64(pg, &grid[idx]);
            svfloat64_t left = svld1_f64(pg, &grid[idx-1]);
            svfloat64_t right = svld1_f64(pg, &grid[idx+1]);
            
            svfloat64_t sum = svadd_x(pg, center, left);
            sum = svadd_x(pg, sum, right);
            
            svfloat64_t result = svmul_x(pg, sum, weight_vec);
            svst1_f64(pg, &new_grid[idx], result);
        }
    }
}
 
__arm_new("za")
void stencil2D_5point_sme(double* __restrict__ grid, double* __restrict__ new_grid, int rows, int cols, int stride )
__arm_streaming {
    uint64_t SVL = svcntd();
    svfloat64_t weight_vec = svdup_f64(1.0 / 5.0);
    svbool_t pg_all = svptrue_b64();
    
        for(int i=1; i<rows-1; i+=stride) {
            for(int j=1; j<cols-1; j+= SVL*stride) {
                int j_limit = (cols-1<j+SVL*stride-1) ? cols-1 : j+SVL*stride-1;
                svbool_t pg = svwhilelt_b64(j, j_limit + 1);
                if( !svptest_any(svptrue_b64(), pg)) break;
                
                int base_idx = i*cols + j;
                
                svfloat64_t center = svld1_f64(pg, &grid[base_idx]);
                svfloat64_t top = svld1_f64(pg, &grid[base_idx-cols]);
                svfloat64_t bottom = svld1_f64(pg, &grid[base_idx+cols]);
                svfloat64_t left = svld1_f64(pg, &grid[base_idx-1]);
                svfloat64_t right = svld1_f64(pg, &grid[base_idx+1]);
                
                svfloat64_t sum = svadd_x(pg, center, top);
                sum = svadd_x(pg, sum, bottom);
                sum = svadd_x(pg, sum, left);
                sum = svadd_x(pg, sum, right);
                
                svfloat64_t result = svmul_x(pg, sum, weight_vec);
                svst1_f64(pg, &new_grid[base_idx], result);
            }
        }
    
}

__arm_new("za")
void stencil2D_9point_sme(double* __restrict__ grid, double* __restrict__ new_grid, int rows, int cols, int stride )
__arm_streaming {
    uint64_t SVL = svcntd();
    int plane_size = rows * cols;
    svfloat64_t weight_vec = svdup_f64(1.0 / 9.0);
    svbool_t pg_all = svptrue_b64();
    
        for(int i=1; i<rows-1; i+=stride) {
            for(int j=1; j<cols-1; j+= SVL*stride) {
                int j_limit = (cols-1<j+SVL*stride-1) ? cols-1 : j+SVL*stride-1;
                svbool_t pg = svwhilelt_b64(j, j_limit + 1);
                if( !svptest_any(svptrue_b64(), pg)) break;
                
                int base_idx = i*cols + j;
                
                svfloat64_t m_i1_j1 = svld1_f64(pg, &grid[(i-1)*cols + (j-1)]);
                svfloat64_t m_i1_j0 = svld1_f64(pg, &grid[(i-1)*cols + j]);
                svfloat64_t m_i1_jp1 = svld1_f64(pg, &grid[(i-1)*cols + (j+1)]);
                
                svfloat64_t m_i0_j1 = svld1_f64(pg, &grid[i*cols + (j-1)]);
                svfloat64_t center = svld1_f64(pg, &grid[i*cols + j]);
                svfloat64_t m_i0_jp1 = svld1_f64(pg, &grid[i*cols + (j+1)]);
                
                svfloat64_t m_ip1_j1 = svld1_f64(pg, &grid[(i+1)*cols + (j-1)]);
                svfloat64_t m_ip1_j0 = svld1_f64(pg, &grid[(i+1)*cols + j]);
                svfloat64_t m_ip1_jp1 = svld1_f64(pg, &grid[(i+1)*cols + (j+1)]);
                
                svfloat64_t sum = svadd_x(pg, m_i1_j1, m_i1_j0);
                sum = svadd_x(pg, sum, m_i1_jp1);
                sum = svadd_x(pg, sum, m_i0_j1);
                sum = svadd_x(pg, sum, center);
                sum = svadd_x(pg, sum, m_i0_jp1);
                sum = svadd_x(pg, sum, m_ip1_j1);
                sum = svadd_x(pg, sum, m_ip1_j0);
                sum = svadd_x(pg, sum, m_ip1_jp1);
                
                svfloat64_t result = svmul_x(pg, sum, weight_vec);
                svst1_f64(pg, &new_grid[base_idx], result);
            }
        }
}

__arm_new("za")
void stencil3D_13point_sme(double* __restrict__ grid, double* __restrict__ new_grid, int depth, int rows, int cols, int stride )
__arm_streaming {
    uint64_t SVL = svcntd();
    int plane_size = rows * cols;
    svfloat64_t weight_vec = svdup_f64(1.0 / 13.0);
    svfloat64_t ones = svdup_f64(1.0);
    svbool_t pg_all = svptrue_b64();
    
    for(int k=1; k<depth-1; k+=stride) {
        for(int i=1; i<rows-1; i+=stride) {
            for(int j=1; j<cols-1; j+= SVL*stride) {
                int j_limit = (cols-1<j+SVL*stride-1) ? cols-1 : j+SVL*stride-1;
                svbool_t pg = svwhilelt_b64(j, j_limit + 1);
                if( !svptest_any(svptrue_b64(), pg)) break;
                
                int base_idx = k*plane_size + i*cols + j;
                
                svfloat64_t center = svld1_f64(pg, &grid[base_idx]);
                
                svfloat64_t k1_i0_j0 = svld1_f64(pg, &grid[(k-1) * plane_size + i * cols + j]);
                svfloat64_t kp1_i0_j0 = svld1_f64(pg, &grid[(k+1) * plane_size + i * cols + j]);
                svfloat64_t k0_i1_j0 = svld1_f64(pg, &grid[k * plane_size + (i-1) * cols + j]);
                svfloat64_t k0_ip1_j0 = svld1_f64(pg, &grid[k * plane_size + (i+1) * cols + j]);
                svfloat64_t k0_i0_j1 = svld1_f64(pg, &grid[k * plane_size + i * cols + (j-1)]);
                svfloat64_t k0_i0_jp1 = svld1_f64(pg, &grid[k * plane_size + i * cols + (j+1)]);
                
                svfloat64_t k1_i1_j0 = svld1_f64(pg, &grid[(k-1) * plane_size + (i-1) * cols + j]);
                svfloat64_t k1_ip1_j0 = svld1_f64(pg, &grid[(k-1) * plane_size + (i+1) * cols + j]);
                svfloat64_t kp1_i1_j0 = svld1_f64(pg, &grid[(k+1) * plane_size + (i-1) * cols + j]);
                svfloat64_t kp1_ip1_j0 = svld1_f64(pg, &grid[(k+1) * plane_size + (i+1) * cols + j]);
                
                svfloat64_t k1_i0_j1 = svld1_f64(pg, &grid[(k-1) * plane_size + i * cols + (j-1)]);
                svfloat64_t kp1_i0_jp1 = svld1_f64(pg, &grid[(k+1) * plane_size + i * cols + (j+1)]);
                
                svzero_za();
                
                svmopa_za64_f64_m(0, pg_all, pg, ones, center);
                
                svmopa_za64_f64_m(0, pg_all, pg, ones, k1_i0_j0);
                svmopa_za64_f64_m(0, pg_all, pg, ones, kp1_i0_j0);
                svmopa_za64_f64_m(0, pg_all, pg, ones, k0_i1_j0);
                svmopa_za64_f64_m(0, pg_all, pg, ones, k0_ip1_j0);
                svmopa_za64_f64_m(0, pg_all, pg, ones, k0_i0_j1);
                svmopa_za64_f64_m(0, pg_all, pg, ones, k0_i0_jp1);
                
                svmopa_za64_f64_m(0, pg_all, pg, ones, k1_i1_j0);
                svmopa_za64_f64_m(0, pg_all, pg, ones, k1_ip1_j0);
                svmopa_za64_f64_m(0, pg_all, pg, ones, kp1_i1_j0);
                svmopa_za64_f64_m(0, pg_all, pg, ones, kp1_ip1_j0);
                svmopa_za64_f64_m(0, pg_all, pg, ones, k1_i0_j1);
                svmopa_za64_f64_m(0, pg_all, pg, ones, kp1_i0_jp1);
                
                svfloat64_t sum = svread_hor_za64_m(svundef_f64(), pg_all, 0, 0);
                svfloat64_t result = svmul_f64_z(pg, sum, weight_vec);
                svst1_f64(pg, &new_grid[base_idx], result);
                
            }
        }
    }
}

double test_stencil_3d_13point(bool run_stride1, bool run_stride2) {
    std::cout<<std::endl<<"------3d13p-----"<<std::endl;
    const int DEPTH = 128, ROWS = 512, COLS = 512;
    double* g1 = (double*)aligned_alloc(64, DEPTH * ROWS * COLS * sizeof(double));
    double* g2 = (double*)aligned_alloc(64, DEPTH * ROWS * COLS * sizeof(double));
    
    double total_time = 0.0;
    double elapsed;
    
    if(run_stride1) {
        for(int k=0; k<DEPTH; k++)
            for(int i=0; i<ROWS; i++)
                for(int j=0; j<COLS; j++)
                    g1[k*ROWS*COLS + i*COLS + j] = 1.0 + (k*ROWS+i) * COLS + j;
        std::cout<<"stride=1..."<<std::endl;
        auto start = std::chrono::high_resolution_clock::now();
        for(int iter=0; iter<100; iter++) stencil3D_13point_sme(g1, g2, DEPTH, ROWS, COLS, 1);
        auto end = std::chrono::high_resolution_clock::now();
        elapsed = std::chrono::duration<double>(end-start).count();
        std::cout<<"Time:"<<elapsed<<std::endl;
        total_time += elapsed;
    }
    
    if(run_stride2) {
        for(int k=0; k<DEPTH; k++)
            for(int i=0; i<ROWS; i++)
                for(int j=0; j<COLS; j++)
                    g1[k*ROWS*COLS + i*COLS + j] = 1.0 + (k*ROWS+i) * COLS + j;
        std::cout<<"stride=2..."<<std::endl;
        auto start = std::chrono::high_resolution_clock::now();
        for(int iter=0; iter<100; iter++) stencil3D_13point_sme(g1, g2, DEPTH, ROWS, COLS, 2);
        auto end = std::chrono::high_resolution_clock::now();
        elapsed = std::chrono::duration<double>(end-start).count();
        std::cout<<"Time:"<<elapsed<<std::endl;
        total_time += elapsed;
    }
    
    free(g1); free(g2);
    return total_time;
}

int main(int argc, char* argv[]) {
    // ...根据参数判断执行哪些stencil用例
    test_stencil_3d_13point(true, false);
    test_stencil_3d_13point(false, true);
    // ...记录并输出总运行时间
}
