package cn.byb.appdemo;

import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.stereotype.Component;

import javax.cache.Cache;
import javax.cache.CacheManager;
import javax.cache.Caching;

@EnableCaching
@Component
public class CacheDemo {

    @Bean
    public Cache<String, byte[]> redisCache() {
        CacheManager cacheManager =
                Caching.getCacheManager(Thread.currentThread().getContextClassLoader(), "appdemo");
        return cacheManager.getCache("key");
    }
}
